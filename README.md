# 🚀 Disperse-Collect API

This project implements a Rocket-based RESTful API for interacting with the **DisperseCollect** smart contract. The API allows you to disperse ETH and ERC20 tokens to multiple recipients, commit tokens, and collect them from multiple payers. Built with **Rust**, **ethers-rs**, and **Rocket**, it also features **OpenAPI** documentation via Swagger and RapiDoc.

🔗 **Smart Contract Address**:  
**Linea Sepolia Testnet**: `0x40B96ce6ebCe3e2327aB81D61C51492b2eA3258d`, 
lineacan: `https://sepolia.lineascan.build/address/0x40b96ce6ebce3e2327ab81d61c51492b2ea3258d`

## 🌟 Features

- ⚡ **Disperse ETH**: Send ETH to multiple addresses with support for percentage-based or fixed amounts.
- 🪙 **Disperse ERC20 Tokens**: Distribute ERC20 tokens to several recipients in percentage-based or fixed amounts.
- 🛠 **Commit**: Store ETH or ERC20 tokens for future collection.
- 💸 **Collect**: Collect ETH or ERC20 tokens from multiple payers to a single address.
- 📄 **OpenAPI Documentation**: Includes **Swagger UI** and **RapiDoc** interfaces for easy API exploration.
- 🩺 **Health Check**: Simple health check endpoint to ensure the server is running.

## 📬 API Endpoints

- `POST /disperse-eth` ➡️ Disperse ETH to multiple addresses.
- `POST /disperse-erc20` ➡️ Disperse ERC20 tokens to multiple addresses.
- `POST /commit` ➡️ Commit ETH or ERC20 tokens for future use.
- `POST /collect` ➡️ Collect ETH or ERC20 tokens from multiple payers.
- `GET /health` 🩺 Check if the server is running.
- `GET /swagger` 📜 Swagger UI for API documentation.
- `GET /docs` 📘 RapiDoc interface for API documentation.

## 🛠️ Technologies

- 🦀 **Rust**: Backend API development.
- 🔥 **Rocket**: Web framework for handling HTTP requests.
- 🌐 **ethers-rs**: For interacting with the Ethereum blockchain and smart contracts.
- 🔄 **serde** and **serde_json**: For JSON serialization/deserialization.
- 📘 **OpenAPI**: Integrated for automatically generating API documentation.

## 🚀 Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Opticonomy/disperse-collect.git
   cd disperse-collect
   ```

2. **Set up environment variables** (in `.env`):
   - `LINEA_SEPOLIA_RPC_URL`: Your Ethereum node RPC URL.
   - `PRIVATE_KEY`: Private key for signing transactions (connected to the deployed contract).

3. **Build and run the API server**:
   ```bash
   cd rust-api
   cargo run
   ```

4. **Access the API documentation**:
   - 🌐 **Swagger UI**: [http://localhost:8000/swagger](http://localhost:8000/swagger)
   - 📘 **RapiDoc**: [http://localhost:8000/docs](http://localhost:8000/docs)

## 🔗 Smart Contract Details

The **DisperseCollect** contract is deployed on the Linea Sepolia Testnet.

- **Contract Address**: `0x40B96ce6ebCe3e2327aB81D61C51492b2eA3258d`
- **Network**: Linea Sepolia Testnet (Chain ID: 59141)

🎉 **Happy Dispersing and Collecting!**
