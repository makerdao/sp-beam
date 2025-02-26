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

import {DssInstance} from "dss-test/MCD.sol";
import {DSPCInstance} from "./DSPCInstance.sol";

interface DSPCLike {
    function rely(address usr) external;
    function file(bytes32 what, uint256 data) external;
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
    function kiss(address usr) external;
}

interface DSPCMomLike {
    function setAuthority(address usr) external;
}

/// @title Configuration parameters for a collateral type in DSPC
/// @dev Used to configure rate parameters for a specific collateral
struct DSPCIlkConfig {
    bytes32 ilk;
    /// @dev Collateral identifier
    uint16 min;
    /// @dev Minimum rate in basis points [0-65535]
    uint16 max;
    /// @dev Maximum rate in basis points [0-65535]
    uint16 step;
}
/// @dev Step size in basis points [0-65535]

/// @title Global configuration parameters for DSPC
/// @dev Used to configure global parameters and collateral-specific settings
struct DSPCConfig {
    uint256 tau;
    /// @dev Time delay between rate updates
    DSPCIlkConfig[] ilks;
}
/// @dev Array of collateral configurations

/// @title Dynamic Stability Parameter Controller Initialization
/// @notice Handles initialization and configuration of the DSPC contract
/// @dev Sets up permissions and configures parameters for the DSPC system
library DSPCInit {
    /// @notice Initializes a DSPC instance with the specified configuration
    /// @dev Sets up permissions between DSPC and core contracts, and configures parameters
    /// @param dss The DSS (MakerDAO) instance containing core contract references
    /// @param inst The DSPC instance containing contract addresses
    /// @param cfg The configuration parameters for DSPC
    function init(DssInstance memory dss, DSPCInstance memory inst, DSPCConfig memory cfg) internal {
        // Set up permissions
        DSPCLike dspc = DSPCLike(inst.dspc);
        DSPCMomLike mom = DSPCMomLike(inst.mom);

        // Authorize DSPCMom in DSPC
        dspc.rely(inst.mom);

        // Set DSPCMom authority to MCD_ADM
        mom.setAuthority(dss.chainlog.getAddress("MCD_ADM"));

        // Authorize DSPC in core contracts
        dss.jug.rely(inst.dspc);
        dss.pot.rely(inst.dspc);
        DSPCLike(dss.chainlog.getAddress("SUSDS")).rely(inst.dspc);

        // Configure global parameters
        dspc.file("tau", cfg.tau);

        // Configure ilks
        for (uint256 i = 0; i < cfg.ilks.length; i++) {
            DSPCIlkConfig memory ilk = cfg.ilks[i];
            dspc.file(ilk.ilk, "max", uint256(ilk.max));
            dspc.file(ilk.ilk, "min", uint256(ilk.min));
            dspc.file(ilk.ilk, "step", uint256(ilk.step));
        }
    }
}
