const hre = require("hardhat");
const BigNumber = require("bignumber.js");


async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log('Deploying WakaToken, TokenStaking contract with address:', deployerAddress);

  const WakaToken = await hre.ethers.getContractFactory("WakaToken");
  const TokenStaking = await hre.ethers.getContractFactory("TokenStaking");

  const wakaToken = await WakaToken.deploy();
  console.log('WakaToken contract deployed at', wakaToken.address);

  const WakaPerBlock = new BigNumber(7).multipliedBy(10**16).toFixed(0);
  const tokenStaking = await TokenStaking.deploy(wakaToken.address,  WakaPerBlock);
  console.log('TokenStaking contract deployed at', tokenStaking.address);




  // const TokenStaking = await hre.ethers.getContractFactory("TokenStaking");
  // const RewardPool = await hre.ethers.getContractFactory("RewardPool");

  // const tokenStaking = await TokenStaking.deploy("0xacD09f2a5F1612522c632bA4b1E515f6296ec506", 1654152000);
  // console.log('TokenStaking contract deployed at', tokenStaking.address);

  // const rewardPool = await RewardPool.deploy(tokenStaking.address, "0xacD09f2a5F1612522c632bA4b1E515f6296ec506");
  // console.log('RewardPool contract deployed at', rewardPool.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
