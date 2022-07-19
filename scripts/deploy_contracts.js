const hre = require("hardhat");
const BigNumber = require("bignumber.js");


async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log('Deploying SBCToken, TokenStaking contract with address:', deployerAddress);

  // const SBCToken = await hre.ethers.getContractFactory("SBCToken");
  // const TokenStaking = await hre.ethers.getContractFactory("TokenStaking");

  // const sbcToken = await (await SBCToken.deploy()).deployed();
  // console.log('SBCToken contract deployed at', sbcToken.address);

  // const sbcPerBlock = new BigNumber(7).multipliedBy(10**16).toFixed(0);
  // const tokenStaking = await TokenStaking.deploy(sbcToken.address, 26400000, sbcPerBlock);
  // console.log('TokenStaking contract deployed at', tokenStaking.address);




  const TokenStaking = await hre.ethers.getContractFactory("TokenStaking");
  const RewardPool = await hre.ethers.getContractFactory("RewardPool");

  const tokenStaking = await TokenStaking.deploy("0xacD09f2a5F1612522c632bA4b1E515f6296ec506", 1654152000);
  console.log('TokenStaking contract deployed at', tokenStaking.address);

  const rewardPool = await RewardPool.deploy(tokenStaking.address, "0xacD09f2a5F1612522c632bA4b1E515f6296ec506");
  console.log('RewardPool contract deployed at', rewardPool.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
