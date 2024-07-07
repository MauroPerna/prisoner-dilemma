import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

/**
 * Deploys a contract named "PrisonersDilemma" using the deployer account
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployPrisonersDilemma: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("PrisonersDilemma", {
    from: deployer,
    // Contract constructor arguments, if any. Update the args array as per your constructor.
    args: [], // Assuming there are no constructor arguments. Add arguments if needed.
    log: true,
    autoMine: true, // Automatically mine the deployment transaction on local networks
  });

  // Get the deployed contract to interact with it after deploying.
  const prisonersDilemma = await hre.ethers.getContract<Contract>("PrisonersDilemma", deployer);
  console.log("📝 PrisonersDilemma contract deployed at:", prisonersDilemma.address);
};

export default deployPrisonersDilemma;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags PrisonersDilemma
deployPrisonersDilemma.tags = ["PrisonersDilemma"];
