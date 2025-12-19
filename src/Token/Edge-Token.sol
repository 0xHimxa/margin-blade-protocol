// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Edge Token
 * @author Your Name/Project
 * @notice Standard ERC20 implementation for the Edge ecosystem with mint and burn capabilities.
 */
contract Edge is ERC20, Ownable {
    ///////////////////
    // Errors
    ///////////////////
    error EDGEToken__AmountCantBeZero();
    error EDGEToken__NotAuthorized(); // Placeholder for access control

    ///////////////////
    // Modifiers
    ///////////////////
    modifier minimumChecks(uint256 _amount) {
        if (_amount <= 0) {
            revert EDGEToken__AmountCantBeZero();
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {}

    ///////////////////
    // External Functions
    ///////////////////

    /**
     * @notice Creates new tokens and assigns them to the specified address.
     * @dev Warning: In a real-world scenario, this should be protected by an 'onlyOwner'
     * or 'onlyMinter' modifier to prevent unauthorized inflation.
     * @param _to The address receiving the minted tokens.
     * @param _amount The quantity of tokens to be created.
     */
    function mint(address _to, uint256 _amount) external minimumChecks(_amount) onlyOwner returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    /**
     * @notice Destroys tokens from a specific address.
     * @dev Usually used by the engine/protocol to maintain the peg or reduce supply.
     * @param _amount The quantity of tokens to be destroyed.
     */
    function burn(uint256 _amount) external minimumChecks(_amount) onlyOwner {
        _burn(msg.sender, _amount);
    }
}
