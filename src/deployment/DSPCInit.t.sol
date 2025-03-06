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
import {DSPC} from "../DSPC.sol";
import {DSPCMom} from "../DSPCMom.sol";
import {DSPCDeploy, DSPCDeployParams} from "./DSPCDeploy.sol";
import {DSPCInit, DSPCConfig, DSPCRateConfig} from "./DSPCInit.sol";
import {DSPCInstance} from "./DSPCInstance.sol";
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
    function init(DssInstance memory dss, DSPCInstance memory inst, DSPCConfig memory cfg) external {
        DSPCInit.init(dss, inst, cfg);
    }
}

contract DSPCInitTest is DssTest {
    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address deployer = address(0xDE9);
    address owner = address(0x123);
    address pause;
    address susds;
    ProxyLike pauseProxy;
    InitCaller caller;

    DssInstance dss;
    ConvMock conv;
    DSPCInstance inst;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        pauseProxy = ProxyLike(dss.chainlog.getAddress("MCD_PAUSE_PROXY"));
        pause = dss.chainlog.getAddress("MCD_PAUSE");
        conv = new ConvMock();
        susds = dss.chainlog.getAddress("SUSDS");
        caller = new InitCaller();

        vm.startPrank(deployer);
        inst = DSPCDeploy.deploy(
            DSPCDeployParams({
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
        DSPCRateConfig[] memory ilks = new DSPCRateConfig[](2);

        // Configure ETH-A
        ilks[0] = DSPCRateConfig({
            id: "ETH-A",
            min: uint16(0), // 0%
            max: uint16(1000), // 10%
            step: uint16(50) // 0.5%
        });

        // Configure WBTC-A
        ilks[1] = DSPCRateConfig({
            id: "WBTC-A",
            min: uint16(0), // 0%
            max: uint16(1500), // 15%
            step: uint16(100) // 1%
        });

        DSPCConfig memory cfg = DSPCConfig({tau: 1 days, ilks: ilks, bud: address(0x0ddaf)});

        vm.prank(pause);
        pauseProxy.exec(address(caller), abi.encodeCall(caller.init, (dss, inst, cfg)));

        // Verify DSPCMom authority
        assertEq(DSPCMom(inst.mom).authority(), dss.chainlog.getAddress("MCD_ADM"), "Wrong authority");

        // Verify DSPC permissions
        assertEq(DSPC(inst.dspc).wards(inst.mom), 1, "Mom not authorized in DSPC");

        // Verify core contract permissions
        assertEq(JugLike(address(dss.jug)).wards(inst.dspc), 1, "DSPC not authorized in Jug");
        assertEq(PotLike(address(dss.pot)).wards(inst.dspc), 1, "DSPC not authorized in Pot");
        assertEq(SUSDSLike(susds).wards(inst.dspc), 1, "DSPC not authorized in SUSDS");

        // Verify configuration
        assertEq(DSPC(inst.dspc).tau(), cfg.tau, "Wrong tau");
        assertEq(DSPC(inst.dspc).buds(cfg.bud), 1, "Wrong bud");

        // Verify ETH-A config
        DSPC.Cfg memory ethCfg = DSPC(inst.dspc).cfgs("ETH-A");
        assertEq(ethCfg.min, ilks[0].min, "Wrong ETH-A min");
        assertEq(ethCfg.max, ilks[0].max, "Wrong ETH-A max");
        assertEq(ethCfg.step, ilks[0].step, "Wrong ETH-A step");

        // Verify WBTC-A config
        DSPC.Cfg memory wbtcCfg = DSPC(inst.dspc).cfgs("WBTC-A");
        assertEq(wbtcCfg.min, ilks[1].min, "Wrong WBTC-A min");
        assertEq(wbtcCfg.max, ilks[1].max, "Wrong WBTC-A max");
        assertEq(wbtcCfg.step, ilks[1].step, "Wrong WBTC-A step");
    }
}
