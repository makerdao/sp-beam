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

interface JugLike {
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
    function ilks(bytes32 ilk) external view returns (uint256 duty, uint256 rho);
    function drip(bytes32 ilk) external;
}

interface PotLike {
    function file(bytes32 what, uint256 data) external;
    function dsr() external view returns (uint256);
    function drip() external;
}

interface SUSDSLike {
    function file(bytes32 what, uint256 data) external;
    function ssr() external view returns (uint256);
    function drip() external;
}

interface ConvLike {
    function btor(uint256 bps) external pure returns (uint256 ray);
    function rtob(uint256 ray) external pure returns (uint256 bps);
}

/// @title Direct Stability Parameters Change Module (DSPC)
/// @notice A module for managing protocol stability parameters with configurable constraints and safety checks
/// @dev Provides controlled access to modify stability parameters (ilk stability fees, DSR, SSR) with:
///      - Configurable min/max bounds and step sizes for each parameter
///      - Cooldown periods between updates
///      - Ordered batch updates
///      - Emergency circuit breaker
/// @custom:authors [Oddaf]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract DSPC {
    // --- Structs ---
    /// @notice Configuration for a rate parameter's constraints
    /// @dev All values are in basis points (1 bp = 0.01%)
    struct Cfg {
        uint16 min; // Minimum allowed rate
        uint16 max; // Maximum allowed rate
        uint16 step; // Maximum allowed rate change per update
    }

    /// @notice A rate parameter update request
    /// @dev Used in batch updates to modify multiple rates atomically
    struct ParamChange {
        bytes32 id; // Rate identifier (ilk, "DSR", or "SSR")
        uint256 bps; // New rate value in bps
    }

    // --- Immutables ---
    /// @notice Stability fee rates
    JugLike public immutable jug;
    /// @notice DSR rate
    PotLike public immutable pot;
    /// @notice SSR rate
    SUSDSLike public immutable susds;
    /// @notice Rate conversion utility
    ConvLike public immutable conv;

    // --- Storage Variables ---
    /// @notice Mapping of admin addresses
    mapping(address => uint256) public wards;
    /// @notice Mapping of addresses that can operate this module
    mapping(address => uint256) public buds;
    /// @notice Mapping of rate constraints
    mapping(bytes32 => Cfg) public cfgs;
    /// @notice Circuit breaker flag
    uint8 public bad;
    /// @notice Cooldown period between rate changes in seconds
    uint64 public tau;
    /// @notice Last time when rates were updated (Unix timestamp)
    uint128 public toc;

    // --- Events ---
    /**
     * @notice `usr` was granted admin access.
     * @param usr The user address.
     */
    event Rely(address indexed usr);
    /**
     * @notice `usr` admin access was revoked.
     * @param usr The user address.
     */
    event Deny(address indexed usr);
    /**
     * @notice `usr` was granted permission to change rates (call set()).
     * @param usr The user address.
     */
    event Kiss(address indexed usr);
    /**
     * @notice Permission revoked for `usr` to change rates (call set()).
     * @param usr The user address.
     */
    event Diss(address indexed usr);
    /**
     * @notice A contract parameter was updated.
     * @param what The changed parameter name.
     * @param data The new value of the parameter.
     */
    event File(bytes32 indexed what, uint256 data);
    /**
     * @notice A parameter was updated for an ilk, DSR, SSR.
     * @param id The identifier (ilk, DSR, or SSR).
     * @param what The changed parameter name.
     * @param data The new value of the parameter.
     */
    event File(bytes32 indexed id, bytes32 indexed what, uint256 data);
    /**
     * @notice Rate change was executed.
     * @param id The identifier (ilk, DSR, or SSR).
     * @param bps The new rate in basis points.
     */
    event Set(bytes32 indexed id, uint256 bps);

    // --- Modifiers ---
    modifier auth() {
        require(wards[msg.sender] == 1, "DSPC/not-authorized");
        _;
    }

    modifier toll() {
        require(buds[msg.sender] == 1, "DSPC/not-facilitator");
        _;
    }

    modifier good() {
        require(bad == 0, "DSPC/module-halted");
        _;
    }

    /// @notice Initialize the DSPC module with core system contracts
    /// @param _jug Jug contract for stability fee management
    /// @param _pot Pot contract for Dai Savings Rate (DSR)
    /// @param _susds SUSDS contract for Sky Savings Rate (SSR)
    /// @param _conv Utility contract for rate conversions between basis points and ray
    constructor(address _jug, address _pot, address _susds, address _conv) {
        jug = JugLike(_jug);
        pot = PotLike(_pot);
        susds = SUSDSLike(_susds);
        conv = ConvLike(_conv);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- Administration ---
    /// @notice Grant authorization to an address
    /// @param usr The address to be authorized
    /// @dev Sets wards[usr] to 1 and emits Rely event
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    /// @notice Revoke authorization from an address
    /// @param usr The address to be deauthorized
    /// @dev Sets wards[usr] to 0 and emits Deny event
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    /// @notice Add a facilitator
    /// @param usr The address to add as a facilitator
    /// @dev Sets buds[usr] to 1 and emits Kiss event. Facilitators can propose rate updates but cannot modify system parameters
    function kiss(address usr) external auth {
        buds[usr] = 1;
        emit Kiss(usr);
    }

    /// @notice Remove a facilitator
    /// @param usr The address to remove as a facilitator
    /// @dev Sets buds[usr] to 0 and emits Diss event
    function diss(address usr) external auth {
        buds[usr] = 0;
        emit Diss(usr);
    }

    /// @notice Configure global module parameters
    /// @param what Parameter name ("bad": circuit breaker, "tau": cooldown period, "toc": last update timestamp)
    /// @param data New parameter value
    /// @dev Configures critical module parameters:
    ///      - bad: Emergency circuit breaker (0: normal, 1: halted)
    ///      - tau: Minimum time between rate updates in seconds
    ///      - toc: Last update timestamp (set automatically)
    function file(bytes32 what, uint256 data) external auth {
        if (what == "bad") {
            require(data == 0 || data == 1, "DSPC/invalid-bad-value");
            bad = uint8(data);
        } else if (what == "tau") {
            require(data <= type(uint64).max, "DSPC/invalid-tau-value");
            tau = uint64(data);
        } else if (what == "toc") {
            require(data <= type(uint128).max, "DSPC/invalid-toc-value");
            toc = uint128(data);
        } else {
            revert("DSPC/file-unrecognized-param");
        }

        emit File(what, data);
    }

    /// @notice Configure constraints for a specific rate parameter
    /// @param id Rate identifier (ilk for collateral types, "DSR" for Dai Savings Rate, "SSR" for Sky Savings Rate)
    /// @param what Parameter to configure:
    ///      - "min": Minimum allowed rate in basis points
    ///      - "max": Maximum allowed rate in basis points
    ///      - "step": Maximum allowed rate change in basis points
    /// @param data New parameter value in basis points
    /// @dev Important considerations:
    ///      - For ilks, verifies the collateral type is initialized in the system
    ///      - All values must be <= uint16 max (65535 basis points)
    ///      - When setting both min and max, set min first to avoid invalid state
    function file(bytes32 id, bytes32 what, uint256 data) external auth {
        if (id != "DSR" && id != "SSR") {
            (uint256 duty,) = jug.ilks(id);
            require(duty > 0, "DSPC/ilk-not-initialized");
        }
        require(data <= type(uint16).max, "DSPC/invalid-value");
        if (what == "min") {
            require(data <= cfgs[id].max, "DSPC/min-too-high");
            cfgs[id].min = uint16(data);
        } else if (what == "max") {
            require(data >= cfgs[id].min, "DSPC/max-too-low");
            cfgs[id].max = uint16(data);
        } else if (what == "step") {
            cfgs[id].step = uint16(data);
        } else {
            revert("DSPC/file-unrecognized-param");
        }

        emit File(id, what, data);
    }

    /// @notice Execute a batch of rate updates
    /// @param updates Array of rate changes to apply, must be ordered alphabetically by id
    /// @dev Executes multiple rate updates in a single transaction with safety checks:
    ///      1. Verifies cooldown period has elapsed
    ///      2. Checks each rate is configured and within bounds
    ///      3. Validates rate changes don't exceed max step size
    ///      4. Ensures updates are properly ordered to prevent duplicates
    ///      5. Calls drip() before each update to accrue fees
    /// @dev Reverts if:
    ///      - Caller not authorized (DSPC/not-facilitator)
    ///      - Module halted, bad = 1 (DSPC/module-halted)    
    ///      - Empty updates array (DSPC/empty-batch)
    ///      - Cooldown period not elapsed (DSPC/too-early)
    ///      - Updates not ordered alphabetically by id (DSPC/updates-out-of-order)    
    ///      - Rate not configured, step = 0 (DSPC/rate-not-configured)
    ///      - New rate < min (DSPC/below-min)
    ///      - New rate > max (DSPC/above-max)
    ///      - Current rate outside bounds (DSPC/rate-out-of-bounds)
    ///      - Rate change > step (DSPC/delta-above-step)
    function set(ParamChange[] calldata updates) external toll good {
        require(updates.length > 0, "DSPC/empty-batch");
        require(block.timestamp >= tau + toc, "DSPC/too-early");
        toc = uint128(block.timestamp);

        bytes32 last;
        for (uint256 i = 0; i < updates.length; i++) {
            bytes32 id = updates[i].id;

            require(id > last, "DSPC/updates-out-of-order");
            last = id;

            uint256 bps = updates[i].bps;
            Cfg memory cfg = cfgs[id];

            require(cfg.step > 0, "DSPC/rate-not-configured");
            require(bps >= cfg.min, "DSPC/below-min");
            require(bps <= cfg.max, "DSPC/above-max");

            // Check rate change is within allowed gap
            uint256 oldBps;
            if (id == "DSR") {
                oldBps = conv.rtob(PotLike(pot).dsr());
            } else if (id == "SSR") {
                oldBps = conv.rtob(SUSDSLike(susds).ssr());
            } else {
                (uint256 duty,) = JugLike(jug).ilks(id);
                oldBps = conv.rtob(duty);
            }

            require(oldBps >= cfg.min && oldBps <= cfg.max, "DSPC/rate-out-of-bounds");

            // Calculates absolute difference between the old and the new rate
            uint256 delta = bps > oldBps ? bps - oldBps : oldBps - bps;
            require(delta <= cfg.step, "DSPC/delta-above-step");

            // Execute the update
            uint256 ray = conv.btor(bps);
            if (id == "DSR") {
                pot.drip();
                pot.file("dsr", ray);
            } else if (id == "SSR") {
                susds.drip();
                susds.file("ssr", ray);
            } else {
                jug.drip(id);
                jug.file(id, "duty", ray);
            }
            emit Set(id, bps);
        }
    }
}
