// SPDX-FileCopyrightText: 2025 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.24;

interface AuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);
}

interface SPBEAMLike {
    function file(bytes32 what, uint256 data) external;
}

/// @title SPBEAM Mom - Shutdown SPBEAM bypassing GSM delay.
/// @notice Governance contract for halting SPBEAM module operations
/// @dev Provides:
///      - Owner/authority-based access control
///      - Emergency halt without delay
contract SPBEAMMom {
    // --- Auth ---
    /// @notice Owner with full admin rights
    address public owner;
    /// @notice Optional authority contract for additional access control
    address public authority;

    // --- Events ---
    /// @notice Owner address changed
    event SetOwner(address indexed owner);
    /// @notice Authority contract changed
    event SetAuthority(address indexed authority);
    /// @notice SPBEAM module halted
    event Halt(address indexed spbeam);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "SPBEAMMom/not-owner");
        _;
    }

    modifier auth() {
        require(isAuthorized(msg.sender, msg.sig), "SPBEAMMom/not-authorized");
        _;
    }

    /// @notice Initialize contract with msg.sender as owner
    constructor() {
        owner = msg.sender;
        emit SetOwner(msg.sender);
    }

    // --- Administration ---
    /// @notice Transfer ownership to a new address
    /// @param owner_ New owner address with full admin rights
    function setOwner(address owner_) external onlyOwner {
        owner = owner_;
        emit SetOwner(owner_);
    }

    /// @notice Set authority contract for additional access control
    /// @param authority_ New authority contract address (0x0 to disable)
    function setAuthority(address authority_) external onlyOwner {
        authority = authority_;
        emit SetAuthority(authority_);
    }

    // --- Internal Functions ---
    /// @notice Check caller authorization
    /// @param src Caller address
    /// @param sig Function signature
    /// @return True if authorized (owner, self, or approved by authority)
    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == owner || src == address(this)) {
            return true;
        } else if (authority != address(0)) {
            return AuthorityLike(authority).canCall(src, address(this), sig);
        } else {
            return false;
        }
    }

    // --- Emergency Actions ---
    /// @notice Emergency halt of SPBEAM module
    /// @param spbeam Target SPBEAM contract
    /// @dev Sets bad=1 to immediately halt operations
    function halt(address spbeam) external auth {
        SPBEAMLike(spbeam).file("bad", 1);
        emit Halt(spbeam);
    }
}
