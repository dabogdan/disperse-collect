// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DisperseCollect is ReentrancyGuard {
    uint256 public constant PERMILL = 1e6;
    uint256 public constant MAX_ARRAY_SIZE = 300;

    enum TokenType { ETH, ERC20 }

    struct DisperseParams {
        address payable[] recipients;
        uint256[] values;
        uint256 totalAmount;
        bool isPercentages;
        TokenType tokenType;
        IERC20 token; // This will be used only if we are dealing with ERC20 tokens
    }

    modifier validPercentages(uint256[] calldata values, bool isPercentages) {
        if(isPercentages){
            uint256 totalPercentage = 0;
            for (uint i = 0; i < values.length; i++) {
                totalPercentage += values[i];
            }
            require(totalPercentage == PERMILL, "Percentages must add up to 100% (1e6)");
        }
        _;
    }

    address public deployer; // Store the address of the deployer (or collector)

    // This struct stores how much each payer has committed for payment (deferred payment).
    struct Commitment {
        uint256 ethAmount;
        mapping(address => uint256) tokenAmount;
    }

    mapping(address => Commitment) public commitments;

    modifier onlyDeployer() {
        require(msg.sender == deployer, "Not authorized");
        _;
    }

    constructor() {
        deployer = msg.sender; // The deployer is the collector
    }

    // Function to disperse ETH to multiple wallets using percentage or fixed amount
    function disperseETH(
        address payable[] calldata recipients,
        uint256[] calldata values,
        bool isPercentages
    ) external payable nonReentrant validPercentages(values, isPercentages) {
        require(recipients.length == values.length, "Mismatched input lengths");
        require(recipients.length > 0, "No recipients provided");
        require(recipients.length <= MAX_ARRAY_SIZE, "Max array size exceeded");

        DisperseParams memory params = DisperseParams({
            recipients: recipients,
            values: values,
            totalAmount: msg.value,
            isPercentages: isPercentages,
            tokenType: TokenType.ETH,
            token: IERC20(address(0)) // Not used for ETH
        });

        _disperse(params);
    }

    // Function to disperse ERC20 tokens to multiple wallets using percentage or fixed amount
    function disperseERC20(
        IERC20 token,
        address payable[] calldata recipients,
        uint256[] calldata values,
        bool isPercentages
    ) external nonReentrant validPercentages(values, isPercentages) {
        require(recipients.length == values.length, "Mismatched input lengths");
        require(recipients.length > 0, "No recipients provided");
        require(recipients.length <= MAX_ARRAY_SIZE, "Max array size exceeded");

        uint256 totalTokens = token.balanceOf(msg.sender);

        DisperseParams memory params = DisperseParams({
            recipients: recipients,
            values: values,
            totalAmount: totalTokens,
            isPercentages: isPercentages,
            tokenType: TokenType.ERC20,
            token: token
        });

        _disperse(params);
    }

        // Main commit function that handles both ETH and ERC20 tokens
    function commit(TokenType tokenType, IERC20 token, uint256 amount) external payable nonReentrant {
        Commitment storage commitment = commitments[msg.sender];
        if (tokenType == TokenType.ETH) {
            require(msg.value > 0, "No ETH sent");
            commitment.ethAmount += msg.value;
        } else if (tokenType == TokenType.ERC20) {
            require(amount > 0, "No ERC20 tokens committed");
            require(token.allowance(msg.sender, address(this)) >= amount, "Token allowance too low");

            // Transfer tokens from payer to this contract for future collection
            token.transferFrom(msg.sender, address(this), amount);
            commitment.tokenAmount[address(token)] += amount;
        } else {
            revert("Invalid token type");
        }
    }

    // Combined function to collect either ETH or ERC20 tokens from multiple payers
    function collect(TokenType tokenType, IERC20 token, address payable[] calldata payers) external onlyDeployer nonReentrant {
        uint256 totalCollected = 0;

        uint payersLength = payers.length;

        for (uint i = 0; i < payersLength; i++) {
            uint256 committedAmount = _getCommittedAmount(tokenType, token, payers[i]);
            require(committedAmount > 0, "No committed funds");

            totalCollected += committedAmount;

            // Reset the payer's committed amount after collection
            _resetCommitment(tokenType, token, payers[i]);

            // Transfer committed funds to the deployer (collector)
            _transferToCollector(tokenType, token, committedAmount);
        }
    }

    // Internal function to handle both ETH and ERC20 distribution using struct
    function _disperse(DisperseParams memory params) internal {
        uint256 totalDistributed = 0;

        if (params.isPercentages) {
            // Distribute by percentage
            uint recipientsLength = params.recipients.length;
            for (uint i = 0; i < recipientsLength - 1; i++) {
                uint256 amount = (params.totalAmount * params.values[i]) / PERMILL;
                _transfer(params.tokenType, params.recipients[i], amount, params.token);
                totalDistributed += amount;
            }

            // Handle remaining dust
            _transfer(params.tokenType, params.recipients[params.recipients.length - 1], params.totalAmount - totalDistributed, params.token);
        } else {
            // Distribute by fixed amounts
            uint recipientsLength = params.recipients.length;
            for (uint i = 0; i < recipientsLength; i++) {
                totalDistributed += params.values[i];
            }
            require(totalDistributed <= params.totalAmount, "Insufficient balance");

            for (uint i = 0; i < recipientsLength; i++) {
                _transfer(params.tokenType, params.recipients[i], params.values[i], params.token);
            }
        }
    }

    // Internal function to transfer ETH or ERC20 based on token type
    function _transfer(
        TokenType tokenType,
        address recipient,
        uint256 amount,
        IERC20 token
    ) internal {
        if (tokenType == TokenType.ETH) {
            payable(recipient).transfer(amount);
        } else {
            token.transferFrom(msg.sender, recipient, amount);
        }
    }

    // Private helper function to get the committed amount based on token type
    function _getCommittedAmount(TokenType tokenType, IERC20 token, address payer) private view returns (uint256) {
        if (tokenType == TokenType.ETH) {
            return commitments[payer].ethAmount;
        } else {
            return commitments[payer].tokenAmount[address(token)];
        }
    }

    // Private helper function to reset the committed amount after collection
    function _resetCommitment(TokenType tokenType, IERC20 token, address payer) private {
        if (tokenType == TokenType.ETH) {
            commitments[payer].ethAmount = 0;
        } else {
            commitments[payer].tokenAmount[address(token)] = 0;
        }
    }

    // Private helper function to transfer committed funds to the deployer based on token type
    function _transferToCollector(TokenType tokenType, IERC20 token, uint256 amount) private {
        if (tokenType == TokenType.ETH) {
            (bool success, ) = deployer.call{value: amount}("");
            require(success, "ETH Transfer failed");
        } else {
            require(token.transfer(deployer, amount), "ERC20 Transfer failed");
        }
    }

    // Getter for ethAmount
    function getEthAmount(address _payer) public view returns (uint256) {
        return commitments[_payer].ethAmount;
    }

    // Getter for tokenAmount
    function getTokenAmount(address _payer, address _token) public view returns (uint256) {
        return commitments[_payer].tokenAmount[_token];
    }
}