const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("DisperseCollect", function () {
  let DisperseCollect, disperseCollect, MockERC20, mockERC20;
  let owner, alice, bob, charlie;

  beforeEach(async function () {
    [owner, alice, bob, charlie] = await ethers.getSigners();
  
    // Deploy the DisperseCollect contract
    const DisperseCollect = await ethers.getContractFactory("DisperseCollect");
    disperseCollect = await DisperseCollect.deploy();

    // Deploy a mock ERC20 token contract
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockERC20 = await MockERC20.deploy();

    // Wait for the contract to be deployed
    await mockERC20.waitForDeployment(); // ethers v6 syntax

    // Print out the name and symbol to verify
    console.log("MockERC20 Name:", await mockERC20.name());
    console.log("MockERC20 Symbol:", await mockERC20.symbol());

    // You can also print the address of the contract
    console.log("MockERC20 Address:", await mockERC20.getAddress());
});

  
  
  it("should disperse ETH in fixed amounts", async function () {
    const recipients = [alice.address, bob.address, charlie.address];
    const amounts = [
      ethers.parseEther("1"),
      ethers.parseEther("1"),
      ethers.parseEther("1"),
    ];

    // Disperse 3 ETH to recipients
    await disperseCollect.disperseETH(recipients, amounts, false, {
      value: ethers.parseEther("3"),
    });

    // Check balances
    expect(await ethers.provider.getBalance(alice.address)).to.equal(
      ethers.parseEther("10001")
    );
    expect(await ethers.provider.getBalance(bob.address)).to.equal(
      ethers.parseEther("10001")
    );
    expect(await ethers.provider.getBalance(charlie.address)).to.equal(
      ethers.parseEther("10001")
    );
  });

    // Test for dispersing ERC20 tokens in fixed amounts
  it("should disperse ERC20 tokens in fixed amounts", async function () {
    const recipients = [alice.address, bob.address, charlie.address];
    const amounts = [
      ethers.parseEther("100"),
      ethers.parseEther("50"),
      ethers.parseEther("50"),
    ];

    // Mint tokens to the owner for testing
    await mockERC20.mint(owner.address, ethers.parseEther("200"));

    // Approve the DisperseCollect contract to spend tokens on behalf of the owner
    await mockERC20.approve(await disperseCollect.getAddress(), ethers.parseEther("200"));

    // Disperse tokens to recipients
    await disperseCollect.disperseERC20(
      await mockERC20.getAddress(), // Get the correct address of the ERC20 contract
      recipients,
      amounts,
      false
    );

    // Verify token balances
    expect(await mockERC20.balanceOf(alice.address)).to.equal(
      ethers.parseEther("100")
    );
    expect(await mockERC20.balanceOf(bob.address)).to.equal(
      ethers.parseEther("50")
    );
    expect(await mockERC20.balanceOf(charlie.address)).to.equal(
      ethers.parseEther("50")
    );
  });

  // Test for dispersing ERC20 tokens by percentages
  it("should disperse ERC20 tokens by percentages", async function () {
    const recipients = [alice.address, bob.address, charlie.address];
    const percentages = [500000, 250000, 250000]; // 50%, 25%, 25%

    // Mint tokens to the owner for testing
    await mockERC20.mint(owner.address, ethers.parseEther("100"));

    // Approve the DisperseCollect contract to spend tokens on behalf of the owner
    await mockERC20.approve(await disperseCollect.getAddress(), ethers.parseEther("100"));

    // Disperse tokens by percentages
    await disperseCollect.disperseERC20(
      await mockERC20.getAddress(),
      recipients,
      percentages,
      true
    );

    // Verify token balances
    expect(await mockERC20.balanceOf(alice.address)).to.equal(
      ethers.parseEther("50")
    ); // 50% of 100 tokens
    expect(await mockERC20.balanceOf(bob.address)).to.equal(
      ethers.parseEther("25")
    ); // 25% of 100 tokens
    expect(await mockERC20.balanceOf(charlie.address)).to.equal(
      ethers.parseEther("25")
    ); // 25% of 100 tokens
  });

    // Test for committing ETH
    it("should commit ETH", async function () {
        // Commit 1 ETH (passing AddressZero for ETH)
        await disperseCollect.commit(0, "0x0000000000000000000000000000000000000000", 0, { value: ethers.parseEther("1") });
    
        // Retrieve committed ETH amount
        const ethAmount = await disperseCollect.getEthAmount(owner.address);
        expect(ethAmount).to.equal(ethers.parseEther("1"));
    });
  

  // Test for committing ERC20 tokens
  it("should commit ERC20 tokens", async function () {
    const tokenAmountToCommit = ethers.parseEther("50");

    // Mint tokens to the owner for testing
    await mockERC20.mint(owner.address, ethers.parseEther("100"));

    // Approve the DisperseCollect contract to spend tokens on behalf of the owner
    await mockERC20.approve(await disperseCollect.getAddress(), ethers.parseEther("100"));

    // Commit 50 tokens to the contract
    await disperseCollect.commit(1, await mockERC20.getAddress(), tokenAmountToCommit);

    // Retrieve committed token amount
    const tokenAmount = await disperseCollect.getTokenAmount(owner.address, await mockERC20.getAddress());
    expect(tokenAmount).to.equal(tokenAmountToCommit);
  });
});
