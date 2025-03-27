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

import {ScriptTools} from "dss-test/ScriptTools.sol";
import {SPBEAM} from "../SPBEAM.sol";
import {SPBEAMMom} from "../SPBEAMMom.sol";
import {SPBEAMInstance} from "./SPBEAMInstance.sol";

interface MomLike {
    function setOwner(address owner) external;
}

/// @title SPBEAM Deployment Parameters
/// @notice Parameters required for deploying the SPBEAM system
/// @dev Used to configure the initial setup of SPBEAM and SPBEAMMom contracts
struct SPBEAMDeployParams {
    /// @dev Address deploying the contracts
    address deployer;
    /// @dev Final owner address after deployment
    address owner;
    /// @dev MakerDAO Jug contract address
    address jug;
    /// @dev MakerDAO Pot contract address
    address pot;
    /// @dev SUSDS contract address
    address susds;
    /// @dev Rate converter contract address
    address conv;
}

/// @title SPBEAM Deployment Library
/// @notice Handles deployment of SPBEAM system contracts
/// @dev Deploys and configures SPBEAM and SPBEAMMom contracts with proper permissions
library SPBEAMDeploy {
    /// @notice Deploy SPBEAM system contracts
    /// @dev Deploys SPBEAM and SPBEAMMom, sets up initial permissions
    /// @param params Configuration parameters for deployment
    /// @return inst Instance containing addresses of deployed contracts
    function deploy(SPBEAMDeployParams memory params) internal returns (SPBEAMInstance memory inst) {
        // Deploy SPBEAM with core contract references
        inst.spbeam = address(new SPBEAM(params.jug, params.pot, params.susds, params.conv));

        // Deploy SPBEAMMom for governance
        inst.mom = address(new SPBEAMMom());

        // Switch owners
        ScriptTools.switchOwner(inst.spbeam, params.deployer, params.owner);
        MomLike(inst.mom).setOwner(params.owner);
    }
}
