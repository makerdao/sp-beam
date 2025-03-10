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
import {DSPC} from "../DSPC.sol";
import {DSPCMom} from "../DSPCMom.sol";
import {DSPCInstance} from "./DSPCInstance.sol";

interface MomLike {
    function setOwner(address owner) external;
}

/// @title DSPC Deployment Parameters
/// @notice Parameters required for deploying the DSPC system
/// @dev Used to configure the initial setup of DSPC and DSPCMom contracts
struct DSPCDeployParams {
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

/// @title DSPC Deployment Library
/// @notice Handles deployment of DSPC system contracts
/// @dev Deploys and configures DSPC and DSPCMom contracts with proper permissions
library DSPCDeploy {
    /// @notice Deploy DSPC system contracts
    /// @dev Deploys DSPC and DSPCMom, sets up initial permissions
    /// @param params Configuration parameters for deployment
    /// @return inst Instance containing addresses of deployed contracts
    function deploy(DSPCDeployParams memory params) internal returns (DSPCInstance memory inst) {
        // Deploy DSPC with core contract references
        inst.dspc = address(new DSPC(params.jug, params.pot, params.susds, params.conv));

        // Deploy DSPCMom for governance
        inst.mom = address(new DSPCMom());

        // Switch owners
        ScriptTools.switchOwner(inst.dspc, params.deployer, params.owner);
        MomLike(inst.mom).setOwner(params.owner);
    }
}
