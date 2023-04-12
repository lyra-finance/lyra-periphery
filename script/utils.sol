// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

contract Utils is Script {

  /// @dev use this function to write deployed contract address to deployments folder
  function writeJsonToDeploymentsFolder(string memory content) internal {
    string memory inputDir = string.concat(vm.projectRoot(), "/deployments/");
    string memory file = string.concat(vm.toString(block.chainid), ".json");
    vm.writeJson(content, string.concat(inputDir, file));

    console2.log("Written to deployment ", string.concat(inputDir, file));
  }  
}