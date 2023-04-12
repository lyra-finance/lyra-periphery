// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/contracts/token/MultiDistributor.sol";

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import "script/utils.sol";

contract DeployDistributor is Utils {


  /// @dev main function
  function run() external {

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(deployerPrivateKey);

    console2.log("Start deployment! deployer: ", msg.sender);

    MultiDistributor distributor = new MultiDistributor();

    console2.log("Writing to deployments folder");
    string memory outputOb = vm.serializeAddress("key", "distributor", address(distributor));
    writeJsonToDeploymentsFolder(outputOb);

    console2.log("Deployed distributor: ", address(distributor));

    vm.stopBroadcast();
  }
}