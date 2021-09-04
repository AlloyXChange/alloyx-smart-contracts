// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Access is AccessControl {
    bytes32 public constant WHITELIST = keccak256("WHITELIST");
    bytes32 public constant OPERATOR = keccak256("OPERATOR");

    constructor() AccessControl() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        grantRole(WHITELIST, msg.sender);
        grantRole(OPERATOR, msg.sender);
    }

    function hasAccess(address forAddress) public view returns (bool) {
        return hasRole(WHITELIST, forAddress);
    }
}
