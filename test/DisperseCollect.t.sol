// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/DisperseCollect.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // For creating a mock ERC20 token

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DisperseCollectTest is Test {
    DisperseCollect disperseCollect;
    MockERC20 mockERC20;
    address deployer;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    function setUp() public {
        // Deploy the DisperseCollect contract
        disperseCollect = new DisperseCollect();

        // Deploy the MockERC20 contract for testing ERC20 functionality
        mockERC20 = new MockERC20();

        // Set up the deployer
        deployer = address(this);
    }

    function testDisperseETHFixedAmounts() public {
        // Declare and initialize fixed-size arrays with explicit uint256 types
        uint256[3] memory fixedValues = [uint256(1 ether), uint256(1 ether), uint256(1 ether)];
        address payable[3] memory fixedRecipients = [payable(alice), payable(bob), payable(charlie)];

        // Create dynamic arrays
        uint256[] memory values = new uint256[](fixedValues.length);
        address payable[] memory recipients = new address payable[](fixedRecipients.length);

        // Manually copy elements from fixed-size arrays to dynamic arrays
        for (uint256 i = 0; i < fixedValues.length; i++) {
            values[i] = fixedValues[i];
            recipients[i] = fixedRecipients[i];
        }

        // Fund the contract with 3 ether and disperse ETH to recipients
        disperseCollect.disperseETH{value: 3 ether}(recipients, values, false);

        // Verify that the recipients received the correct amounts
        assertEq(alice.balance, 1 ether);
        assertEq(bob.balance, 1 ether);
        assertEq(charlie.balance, 1 ether);
    }




    function testDisperseETHPercents() public {
        uint256[] memory values;
        values[0] = 500000; // 50%
        values[1] = 250000; // 25%
        values[2] = 250000; // 25%

        // Recipients array
        address payable[] memory recipients;
        recipients[0] = payable(alice);
        recipients[1] = payable(bob);
        recipients[2] = payable(charlie);

        // Fund the contract with 2 ether and disperse ETH by percentages
        disperseCollect.disperseETH{value: 2 ether}(recipients, values, true);

        // Verify that the recipients received the correct percentages
        assertEq(alice.balance, 1 ether); // 50% of 2 ether
        assertEq(bob.balance, 0.5 ether); // 25% of 2 ether
        assertEq(charlie.balance, 0.5 ether); // 25% of 2 ether
    }

    function testDisperseERC20FixedAmounts() public {
        uint256[] memory values;
        values[0] = 100 ether;
        values[1] = 50 ether;
        values[2] = 50 ether;

        // Recipients array
        address payable[] memory recipients;
        recipients[0] = payable(alice);
        recipients[1] = payable(bob);
        recipients[2] = payable(charlie);

        // Mint tokens to deployer for testing
        mockERC20.mint(deployer, 200 ether);

        // Approve the DisperseCollect contract to spend tokens on behalf of deployer
        mockERC20.approve(address(disperseCollect), 200 ether);

        // Disperse tokens to recipients
        disperseCollect.disperseERC20(mockERC20, recipients, values, false);

        // Verify that recipients received the correct amounts
        assertEq(mockERC20.balanceOf(alice), 100 ether);
        assertEq(mockERC20.balanceOf(bob), 50 ether);
        assertEq(mockERC20.balanceOf(charlie), 50 ether);
    }

    function testDisperseERC20Percents() public {
        uint256[] memory values;
        values[0] = 500000; // 50%
        values[1] = 250000; // 25%
        values[2] = 250000; // 25%

        // Recipients array
        address payable[] memory recipients;
        recipients[0] = payable(alice);
        recipients[1] = payable(bob);
        recipients[2] = payable(charlie);

        // Mint tokens to deployer for testing
        mockERC20.mint(deployer, 100 ether);

        // Approve the DisperseCollect contract to spend tokens on behalf of deployer
        mockERC20.approve(address(disperseCollect), 100 ether);

        // Disperse tokens by percentages to recipients
        disperseCollect.disperseERC20(mockERC20, recipients, values, true);

        // Verify that recipients received the correct percentages
        assertEq(mockERC20.balanceOf(alice), 50 ether); // 50% of 100 ether
        assertEq(mockERC20.balanceOf(bob), 25 ether); // 25% of 100 ether
        assertEq(mockERC20.balanceOf(charlie), 25 ether); // 25% of 100 ether
    }
   function testCommitETH() public {
        // Commit 1 ether to the contract
        disperseCollect.commit{value: 1 ether}(DisperseCollect.TokenType.ETH, IERC20(address(0)), 0);

        // Use the getter to retrieve the ethAmount for the deployer
        uint256 ethAmount = disperseCollect.getEthAmount(address(this));

        // Verify the ethAmount in the commitment for the deployer
        assertEq(ethAmount, 1 ether);
    }

    function testCommitERC20() public {
        // Mint tokens to deployer for testing
        mockERC20.mint(deployer, 100 ether);

        // Approve the DisperseCollect contract to spend tokens on behalf of deployer
        mockERC20.approve(address(disperseCollect), 100 ether);

        // Commit 50 tokens to the contract
        disperseCollect.commit(DisperseCollect.TokenType.ERC20, mockERC20, 50 ether);

        // Use the getter to retrieve the tokenAmount for the deployer and the ERC20 token
        uint256 tokenAmount = disperseCollect.getTokenAmount(address(this), address(mockERC20));

        // Verify the tokenAmount in the commitment for the deployer
        assertEq(tokenAmount, 50 ether);
    }
}
