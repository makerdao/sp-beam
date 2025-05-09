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

import {DssTest, MCD} from "dss-test/DssTest.sol";
import {DssInstance} from "dss-test/MCD.sol";
import {SPBEAM} from "../SPBEAM.sol";
import {SPBEAMMom} from "../SPBEAMMom.sol";
import {SPBEAMDeploy, SPBEAMDeployParams} from "./SPBEAMDeploy.sol";
import {SPBEAMInit, SPBEAMConfig, SPBEAMRateConfig} from "./SPBEAMInit.sol";
import {SPBEAMInstance} from "./SPBEAMInstance.sol";
import {ConvMock} from "../mocks/ConvMock.sol";

interface RelyLike {
    function rely(address usr) external;
}

interface JugLike is RelyLike {
    function wards(address) external view returns (uint256);
    function ilks(bytes32) external view returns (uint256 duty, uint256 rho);
}

interface PotLike is RelyLike {
    function wards(address) external view returns (uint256);
    function dsr() external view returns (uint256);
}

interface SUSDSLike is RelyLike {
    function wards(address) external view returns (uint256);
    function ssr() external view returns (uint256);
}

interface ConvLike {
    function rtob(uint256 ray) external pure returns (uint256 bps);
}

interface ProxyLike {
    function exec(address usr, bytes memory fax) external returns (bytes memory out);
}

contract InitCaller {
    function init(DssInstance memory dss, SPBEAMInstance memory inst, SPBEAMConfig memory cfg) external {
        SPBEAMInit.init(dss, inst, cfg);
    }
}

contract SPBEAMInitTest is DssTest {
    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address deployer = address(0xDE9);
    address owner = address(0x123);
    address pause;
    address susds;
    ProxyLike pauseProxy;
    InitCaller caller;

    DssInstance dss;
    ConvMock conv;
    SPBEAMInstance inst;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        pauseProxy = ProxyLike(dss.chainlog.getAddress("MCD_PAUSE_PROXY"));
        pause = dss.chainlog.getAddress("MCD_PAUSE");
        conv = new ConvMock();
        susds = dss.chainlog.getAddress("SUSDS");
        caller = new InitCaller();

        vm.startPrank(deployer);
        inst = SPBEAMDeploy.deploy(
            SPBEAMDeployParams({
                deployer: deployer,
                owner: address(pauseProxy),
                jug: address(dss.jug),
                pot: address(dss.pot),
                susds: susds,
                conv: address(conv)
            })
        );
        vm.stopPrank();
    }

    function test_init() public {
        // Create test configuration
        SPBEAMRateConfig[] memory ilks = new SPBEAMRateConfig[](2);

        // Configure ETH-A
        ilks[0] = SPBEAMRateConfig({
            id: "ETH-A",
            min: uint16(0), // 0%
            max: uint16(1000), // 10%
            step: uint16(50) // 0.5%
        });

        // Configure WBTC-A
        ilks[1] = SPBEAMRateConfig({
            id: "WBTC-A",
            min: uint16(0), // 0%
            max: uint16(1500), // 15%
            step: uint16(100) // 1%
        });

        SPBEAMConfig memory cfg = SPBEAMConfig({tau: 1 days, ilks: ilks, bud: address(0x0ddaf)});

        vm.prank(pause);
        pauseProxy.exec(address(caller), abi.encodeCall(caller.init, (dss, inst, cfg)));

        // Verify SPBEAMMom authority
        assertEq(SPBEAMMom(inst.mom).authority(), dss.chainlog.getAddress("MCD_ADM"), "Wrong authority");

        // Verify SPBEAM permissions
        assertEq(SPBEAM(inst.spbeam).wards(inst.mom), 1, "Mom not authorized in SPBEAM");

        // Verify core contract permissions
        assertEq(JugLike(address(dss.jug)).wards(inst.spbeam), 1, "SPBEAM not authorized in Jug");
        assertEq(PotLike(address(dss.pot)).wards(inst.spbeam), 1, "SPBEAM not authorized in Pot");
        assertEq(SUSDSLike(susds).wards(inst.spbeam), 1, "SPBEAM not authorized in SUSDS");

        // Verify configuration
        assertEq(SPBEAM(inst.spbeam).tau(), cfg.tau, "Wrong tau");
        assertEq(SPBEAM(inst.spbeam).buds(cfg.bud), 1, "Wrong bud");

        // Verify ETH-A config
        (uint16 min, uint16 max, uint16 step) = SPBEAM(inst.spbeam).cfgs("ETH-A");
        assertEq(min, ilks[0].min, "Wrong ETH-A min");
        assertEq(max, ilks[0].max, "Wrong ETH-A max");
        assertEq(step, ilks[0].step, "Wrong ETH-A step");

        // Verify WBTC-A config
        (min, max, step) = SPBEAM(inst.spbeam).cfgs("WBTC-A");
        assertEq(min, ilks[1].min, "Wrong WBTC-A min");
        assertEq(max, ilks[1].max, "Wrong WBTC-A max");
        assertEq(step, ilks[1].step, "Wrong WBTC-A step");
    }
}
