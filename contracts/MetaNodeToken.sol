// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MetaNodeToken for MetaNodeStake
 * @author CocoaPuffs
 * @notice Deploy through Stake contract, setting corresponding roles,
 *  not making this contract upgradable for now.
 */
contract MetaNodeToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("MetaNodeToken", "MNT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * This should be called after the deployment of the proxy contract
     * @param _minter The privileged address
     */
    function setMinter(address _minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, _minter);
    }

    function mint(uint256 _amount) external onlyRole(MINTER_ROLE) {
        _mint(msg.sender, _amount);
    }
}