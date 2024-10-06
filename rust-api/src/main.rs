#[macro_use] extern crate rocket;

use ethers::prelude::*;
use rocket::serde::{json::Json, Deserialize, Serialize};
use std::sync::Arc;
use dotenv::dotenv;
use std::env;
use ethers::abi::Abi;
use serde_json::Value;
use rocket_okapi::{openapi, openapi_get_routes, rapidoc::*, swagger_ui::*, settings::UrlObject};
use schemars::JsonSchema;


#[derive(Deserialize, Serialize, JsonSchema)]
struct DispersePayload {
    recipients: Vec<String>,
    values: Vec<String>, 
    is_percentages: bool,
    token_address: Option<String>, // Only for ERC20
}

impl DispersePayload {
    fn parse_values(&self) -> Vec<U256> {
        self.values
            .iter()
            .map(|v| U256::from_dec_str(v).expect("Invalid U256 string"))
            .collect()
    }
}

#[derive(Deserialize, Serialize, JsonSchema)]
struct CommitPayload {
    token_type: String,
    token_address: Option<String>,  // Token address for ERC20
    amount: String,                   
}

impl CommitPayload {
    fn parse_amount(&self) -> Result<U256, String> {
        U256::from_dec_str(&self.amount).map_err(|e| e.to_string())
    }
}

#[derive(Deserialize, Serialize, JsonSchema)]
struct CollectPayload {
    token_type: String,
    token_address: Option<String>,
    payers: Vec<String>,
}

// Health check route
#[openapi]
#[get("/health")]
async fn health() -> &'static str {
    "Server is up and running"
}

#[derive(Deserialize, Serialize, Debug, PartialEq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
enum TokenType {
    ETH,
    ERC20,
}

impl TokenType {
    fn from_str(token_type: &str) -> Result<TokenType, String> {
        match token_type.to_lowercase().as_str() {
            "eth" => Ok(TokenType::ETH),
            "erc20" => Ok(TokenType::ERC20),
            _ => Err(format!("Unknown token type: {}", token_type)),
        }
    }

    fn to_u8(&self) -> u8 {
        match self {
            TokenType::ETH => 0,
            TokenType::ERC20 => 1,
        }
    }
}

fn parse_recipients(recipients: &[String]) -> Vec<Address> {
    recipients
        .iter()
        .map(|recip| recip.parse().unwrap())
        .collect()
}

async fn send_transaction(
    call: ContractCall<SignerMiddleware<Provider<Http>, LocalWallet>, H256>,
) -> Result<Json<String>, String> {
    println!("Sending transaction...");

    // Send the transaction
    let pending_tx = call.send().await.map_err(|e| e.to_string())?;
    
    // Wait for the transaction to be mined
    let tx_hash = pending_tx.await.map_err(|e| e.to_string())?;

    match tx_hash {
        Some(receipt) => Ok(Json(receipt.transaction_hash.to_string())),
        None => Err("Transaction failed or receipt not found".to_string()),
    }
}

async fn setup_contract() -> Result<(Contract<SignerMiddleware<Provider<Http>, LocalWallet>>, Provider<Http>), String> {
    dotenv().ok();
    let rpc_url = env::var("LINEA_SEPOLIA_RPC_URL").expect("LINEA_SEPOLIA_RPC_URL not found");
    let private_key = env::var("PRIVATE_KEY").expect("PRIVATE_KEY not found");

    // Set up provider and wallet
    let provider = Provider::<Http>::try_from(rpc_url).map_err(|e| e.to_string())?;
    let wallet: LocalWallet = private_key.parse::<LocalWallet>().map_err(|e| e.to_string())?;

    let client = SignerMiddleware::new(provider.clone(), wallet.with_chain_id(59141u64));
    let client = Arc::new(client);

    // Load and extract the ABI
    let abi_json = include_str!("../../out/DisperseCollect.sol/DisperseCollect.json");
    let abi_value: Value = serde_json::from_str(abi_json).map_err(|e| e.to_string())?;
    let abi_array = abi_value.get("abi").ok_or("ABI field not found")?.to_string();
    let abi: Abi = serde_json::from_str(&abi_array).map_err(|e| e.to_string())?;

    let contract_address: Address = "0x40B96ce6ebCe3e2327aB81D61C51492b2eA3258d".parse().unwrap();
    let contract = Contract::new(contract_address, abi, client);

    Ok((contract, provider))
}

#[openapi]
#[post("/disperse-eth", format = "application/json", data = "<payload>")]
async fn disperse_eth(payload: Json<DispersePayload>) -> Result<Json<String>, String> {
    let (contract, _provider) = setup_contract().await?;
    
    let recipients = parse_recipients(&payload.recipients);
    let values = payload.parse_values();
    let total_value: U256 = values.iter().fold(U256::zero(), |acc, value| acc + *value);

    let call = contract
        .method::<_, H256>("disperseETH", (recipients, values, payload.is_percentages))
        .map_err(|e| e.to_string())?
        .value(total_value);

    send_transaction(call).await
}

#[openapi]
#[post("/disperse-erc20", format = "application/json", data = "<payload>")]
async fn disperse_erc20(payload: Json<DispersePayload>) -> Result<Json<String>, String> {
    let (contract, _provider) = setup_contract().await?;

    let recipients = parse_recipients(&payload.recipients);
    let values = payload.parse_values();

    let token_address = payload.token_address
        .as_ref()
        .ok_or("Token address is required for ERC20")?
        .parse::<Address>()
        .map_err(|e| format!("Invalid token address: {}", e))?;

    let call = contract
        .method::<_, H256>("disperseERC20", (token_address, recipients, values, payload.is_percentages))
        .map_err(|e| e.to_string())?;

    send_transaction(call).await
}


#[openapi]
#[post("/commit", format = "application/json", data = "<payload>")]
async fn commit(payload: Json<CommitPayload>) -> Result<Json<String>, String> {
    let (contract, _provider) = setup_contract().await?;
    
    let token_type_enum = TokenType::from_str(&payload.token_type).map_err(|e| e.to_string())?;
    let token_type_u8 = token_type_enum.to_u8();
    let amount = payload.parse_amount()?;

    let call = if token_type_u8 == 0 {
        contract
            .method::<_, H256>("commit", (token_type_u8, Address::zero(), amount))
            .map_err(|e| e.to_string())?
            .value(amount)
    } else {
        let token_address = payload.token_address
            .as_ref()
            .ok_or("Token address is required for ERC20")?
            .parse::<Address>()
            .map_err(|e| format!("Invalid token address: {}", e))?;

        contract
            .method::<_, H256>("commit", (token_type_u8, token_address, amount))
            .map_err(|e| e.to_string())?
    };

    send_transaction(call).await
}


#[openapi]
#[post("/collect", format = "application/json", data = "<payload>")]
async fn collect(payload: Json<CollectPayload>) -> Result<Json<String>, String> {
    let (contract, _provider) = setup_contract().await?;

    let token_type_enum = TokenType::from_str(&payload.token_type).map_err(|e| e.to_string())?;
    let token_type_u8 = token_type_enum.to_u8();

    let payers: Vec<Address> = payload.payers.iter().map(|payer| payer.parse().unwrap()).collect();

    let token_address = payload.token_address
        .as_ref()
        .ok_or("Token address is required for ERC20")?
        .parse::<Address>()
        .map_err(|e| format!("Invalid token address: {}", e))?;

    let call = contract
        .method::<_, H256>("collect", (token_type_u8, token_address, payers))
        .map_err(|e| e.to_string())?;

    send_transaction(call).await
}


#[launch]
fn rocket() -> _ {
    rocket::build()
        .mount("/", openapi_get_routes![
            disperse_eth, 
            disperse_erc20, 
            collect, 
            commit, 
            health
        ])
        .mount("/swagger", make_swagger_ui(&SwaggerUIConfig {
            url: "/openapi.json".to_string(),
            ..Default::default()
        }))
        .mount("/docs", make_rapidoc(&RapiDocConfig {
            title: Some("API Documentation".to_string()),
            layout: LayoutConfig {
                layout: Layout::Row,
                render_style: RenderStyle::View,  // Adjust this as needed
                response_area_height: "300px".to_string(),
            },
            general: GeneralConfig {
                spec_urls: vec![UrlObject::new("v1", "/openapi.json")], // Use `UrlObject` to point to the OpenAPI spec
                ..Default::default()
            },
            ..Default::default()
        }))
}
