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

import "dss-test/DssTest.sol";
import {SPBEAM} from "./SPBEAM.sol";
import {SPBEAMMom} from "./SPBEAMMom.sol";
import {ConvMock} from "./mocks/ConvMock.sol";
import {SPBEAMDeploy, SPBEAMDeployParams} from "./deployment/SPBEAMDeploy.sol";
import {SPBEAMInit, SPBEAMConfig, SPBEAMRateConfig} from "./deployment/SPBEAMInit.sol";
import {SPBEAMInstance} from "./deployment/SPBEAMInstance.sol";

interface ConvLike {
    function btor(uint256 bps) external pure returns (uint256 ray);
    function rtob(uint256 ray) external pure returns (uint256 bps);
}

interface SUSDSLike {
    function wards(address usr) external view returns (uint256);
    function ssr() external view returns (uint256);
}

interface ProxyLike {
    function exec(address usr, bytes memory fax) external returns (bytes memory out);
}

contract InitCaller {
    function init(DssInstance memory dss, SPBEAMInstance memory inst, SPBEAMConfig memory cfg) external {
        SPBEAMInit.init(dss, inst, cfg);
    }
}

contract MockBrokenConv {
    function rtob(uint256 /* ray */ ) public pure returns (uint256) {
        return 0;
    }

    function btor(uint256 /* bps */ ) public pure returns (uint256) {
        return 0;
    }
}

contract SPBEAMTest is DssTest {
    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    DssInstance dss;
    SPBEAM beam;
    SPBEAMMom mom;
    ConvLike conv;
    SUSDSLike susds;
    address pause;
    ProxyLike pauseProxy;
    InitCaller caller;
    address bud = address(0xb0d);

    bytes32 constant ILK = "ETH-A";
    bytes32 constant DSR = "DSR";
    bytes32 constant SSR = "SSR";

    event Kiss(address indexed usr);
    event Diss(address indexed usr);
    event File(bytes32 indexed id, bytes32 indexed what, uint256 data);
    event Set(bytes32 indexed id, uint256 bps);

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        pause = dss.chainlog.getAddress("MCD_PAUSE");
        pauseProxy = ProxyLike(dss.chainlog.getAddress("MCD_PAUSE_PROXY"));
        susds = SUSDSLike(dss.chainlog.getAddress("SUSDS"));
        MCD.giveAdminAccess(dss);

        caller = new InitCaller();

        conv = ConvLike(address(new ConvMock()));

        SPBEAMInstance memory inst = SPBEAMDeploy.deploy(
            SPBEAMDeployParams({
                deployer: address(this),
                owner: address(pauseProxy),
                jug: address(dss.jug),
                pot: address(dss.pot),
                susds: address(susds),
                conv: address(conv)
            })
        );
        beam = SPBEAM(inst.spbeam);
        mom = SPBEAMMom(inst.mom);

        // Initialize deployment
        SPBEAMRateConfig[] memory ilks = new SPBEAMRateConfig[](3); // ETH-A, DSR, SSR

        // Configure ETH-A
        ilks[0] = SPBEAMRateConfig({
            id: ILK, // Use the constant bytes32 ILK
            min: uint16(1),
            max: uint16(3000),
            step: uint16(100)
        });

        // Configure DSR
        ilks[1] = SPBEAMRateConfig({
            id: DSR, // Use the constant bytes32 DSR
            min: uint16(1),
            max: uint16(3000),
            step: uint16(100)
        });

        // Configure SSR
        ilks[2] = SPBEAMRateConfig({
            id: SSR, // Use the constant bytes32 SSR
            min: uint16(1),
            max: uint16(3000),
            step: uint16(100)
        });

        SPBEAMConfig memory cfg = SPBEAMConfig({
            tau: 0, // Start with tau = 0 for tests
            ilks: ilks,
            bud: bud
        });
        vm.prank(pause);
        pauseProxy.exec(address(caller), abi.encodeCall(caller.init, (dss, inst, cfg)));
    }

    function test_constructor() public view {
        assertEq(address(beam.jug()), address(dss.jug));
        assertEq(address(beam.pot()), address(dss.pot));
        assertEq(address(beam.susds()), address(susds));
        assertEq(address(beam.conv()), address(conv));

        // init
        assertEq(beam.wards(address(this)), 0);
        assertEq(beam.wards(address(pauseProxy)), 1);
        assertEq(beam.wards(address(mom)), 1);
        assertEq(mom.authority(), dss.chainlog.getAddress("MCD_ADM"));
        assertEq(dss.jug.wards(address(beam)), 1);
        assertEq(dss.pot.wards(address(beam)), 1);
        assertEq(SUSDSLike(dss.chainlog.getAddress("SUSDS")).wards(address(beam)), 1);
    }

    function test_auth() public {
        checkAuth(address(beam), "SPBEAM");
    }

    function test_auth_methods() public {
        checkModifier(address(beam), "SPBEAM/not-authorized", [SPBEAM.kiss.selector, SPBEAM.diss.selector]);
    }

    function test_toll_methods() public {
        checkModifier(address(beam), "SPBEAM/not-facilitator", [SPBEAM.set.selector]);
    }

    function test_good_methods() public {
        vm.startPrank(address(pauseProxy));
        beam.file("bad", 1);
        beam.kiss(address(this));
        vm.stopPrank();

        checkModifier(address(beam), "SPBEAM/module-halted", [SPBEAM.set.selector]);
    }

    function test_kiss() public {
        address who = address(0x0ddaf);
        assertEq(beam.buds(who), 0);

        vm.prank(address(pauseProxy));
        vm.expectEmit(true, true, true, true);
        emit Kiss(who);
        beam.kiss(who);
        assertEq(beam.buds(who), 1);
    }

    function test_diss() public {
        address who = address(0x0ddaf);
        vm.prank(address(pauseProxy));
        beam.kiss(who);
        assertEq(beam.buds(who), 1);

        vm.prank(address(pauseProxy));
        vm.expectEmit(true, true, true, true);
        emit Diss(who);
        beam.diss(who);
        assertEq(beam.buds(who), 0);
    }

    function test_file() public {
        checkFileUint(address(beam), "SPBEAM", ["bad", "tau", "toc"]);

        vm.startPrank(address(pauseProxy));

        vm.expectRevert("SPBEAM/invalid-bad-value");
        beam.file("bad", 2);

        vm.expectRevert("SPBEAM/invalid-tau-value");
        beam.file("tau", uint256(type(uint64).max) + 1);

        vm.expectRevert("SPBEAM/invalid-toc-value");
        beam.file("toc", uint256(type(uint128).max) + 1);

        vm.stopPrank();

        vm.expectRevert("SPBEAM/not-authorized");
        beam.file("bad", 1);
    }

    function test_file_ilk() public {
        (uint16 min, uint16 max, uint16 step) = beam.cfgs(ILK);
        assertEq(min, 1);
        assertEq(max, 3000);
        assertEq(step, 100);

        vm.startPrank(address(pauseProxy));

        vm.expectEmit(true, true, true, true);
        emit File(ILK, "min", 100);
        beam.file(ILK, "min", 100);
        beam.file(ILK, "max", 3000);
        beam.file(ILK, "step", 420);
        vm.stopPrank();

        (min, max, step) = beam.cfgs(ILK);
        assertEq(min, 100);
        assertEq(max, 3000);
        assertEq(step, 420);
    }

    function test_revert_file_ilk_invalid() public {
        vm.startPrank(address(pauseProxy));
        (uint16 min, uint16 max,) = beam.cfgs(ILK);

        vm.expectRevert("SPBEAM/min-too-high");
        beam.file(ILK, "min", max + 1);

        vm.expectRevert("SPBEAM/max-too-low");
        beam.file(ILK, "max", min - 1);

        vm.expectRevert("SPBEAM/file-unrecognized-param");
        beam.file(ILK, "unknown", 100);

        vm.expectRevert("SPBEAM/invalid-value");
        beam.file(ILK, "max", uint256(type(uint16).max) + 1);

        dss.jug.drip("MOG-A");
        vm.expectRevert("SPBEAM/ilk-not-initialized");
        beam.file("MOG-A", "min", 100);

        vm.stopPrank();

        vm.expectRevert("SPBEAM/not-authorized");
        beam.file(ILK, "min", 100);
    }

    function test_set_ilk() public {
        (uint256 duty,) = dss.jug.ilks(ILK);
        uint256 target = conv.rtob(duty) + 50;

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange(ILK, target);

        vm.prank(bud);
        beam.set(updates);

        (duty,) = dss.jug.ilks(ILK);
        assertEq(duty, conv.btor(target));
    }

    function test_set_dsr() public {
        uint256 target = conv.rtob(dss.pot.dsr()) + 50;

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange(DSR, target);

        vm.prank(bud);
        beam.set(updates);

        assertEq(dss.pot.dsr(), conv.btor(target));
    }

    function test_set_ssr() public {
        vm.prank(bud);
        uint256 target = conv.rtob(susds.ssr()) - 50;

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange(SSR, target);

        vm.prank(bud);

        vm.expectEmit(true, true, true, true);
        emit Set(SSR, target);
        beam.set(updates);

        assertEq(susds.ssr(), conv.btor(target));
    }

    function test_set_multiple() public {
        (uint256 duty,) = dss.jug.ilks(ILK);
        uint256 ilkTarget = conv.rtob(duty) - 50;
        uint256 dsrTarget = conv.rtob(dss.pot.dsr()) - 50;
        uint256 ssrTarget = conv.rtob(susds.ssr()) + 50;

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](3);
        updates[0] = SPBEAM.ParamChange(DSR, dsrTarget);
        updates[1] = SPBEAM.ParamChange(ILK, ilkTarget);
        updates[2] = SPBEAM.ParamChange(SSR, ssrTarget);

        vm.prank(bud);
        beam.set(updates);

        (duty,) = dss.jug.ilks(ILK);
        assertEq(duty, conv.btor(ilkTarget));
        assertEq(dss.pot.dsr(), conv.btor(dsrTarget));
        assertEq(susds.ssr(), conv.btor(ssrTarget));
    }

    function test_set_rate_outside_range() public {
        // rate above max
        dss.jug.drip(ILK);
        vm.prank(address(pauseProxy));
        dss.jug.file(ILK, "duty", conv.btor(3050)); // outside range

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange(ILK, 2999);

        vm.prank(bud);
        beam.set(updates);

        (uint256 duty,) = dss.jug.ilks(ILK);
        assertEq(duty, conv.btor(2999));

        // rate below min
        dss.jug.drip(ILK);
        vm.prank(address(pauseProxy));
        dss.jug.file(ILK, "duty", conv.btor(0)); // outside range

        updates[0] = SPBEAM.ParamChange(ILK, 50);

        vm.prank(bud);
        beam.set(updates);

        (duty,) = dss.jug.ilks(ILK);
        assertEq(duty, conv.btor(50));
    }

    function test_revert_set_duplicate() public {
        (uint256 duty,) = dss.jug.ilks(ILK);

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](2);
        updates[0] = SPBEAM.ParamChange(ILK, conv.rtob(duty) - 100);
        updates[1] = SPBEAM.ParamChange(ILK, conv.rtob(duty) - 200); // duplicate, pushing rate beyond step

        vm.prank(bud);
        vm.expectRevert("SPBEAM/updates-out-of-order");
        beam.set(updates);
    }

    function test_revert_set_not_configured_rate() public {
        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange("PEPE-A", 10000);

        vm.prank(bud);
        vm.expectRevert("SPBEAM/rate-not-configured");
        beam.set(updates);
    }

    function test_revert_set_empty() public {
        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](0);

        vm.expectRevert("SPBEAM/empty-batch");
        vm.prank(bud);
        beam.set(updates);
    }

    function test_revert_set_unauthorized() public {
        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange(ILK, 100);

        vm.expectRevert("SPBEAM/not-facilitator");
        beam.set(updates);
    }

    function test_revert_set_below_min() public {
        vm.prank(address(pauseProxy));
        beam.file(ILK, "min", 100);

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange(ILK, 50);

        vm.expectRevert("SPBEAM/below-min");
        vm.prank(bud);
        beam.set(updates);
    }

    function test_revert_set_above_max() public {
        vm.prank(address(pauseProxy));
        beam.file(ILK, "max", 100);

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange(ILK, 150);

        vm.expectRevert("SPBEAM/above-max");
        vm.prank(bud);
        beam.set(updates);
    }

    function test_revert_set_delta_above_step() public {
        vm.prank(address(pauseProxy));
        beam.file(ILK, "step", 100);

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange(ILK, 100);

        vm.expectRevert("SPBEAM/delta-above-step");
        vm.prank(bud);
        beam.set(updates);
    }

    function test_revert_set_before_cooldown() public {
        vm.prank(address(pauseProxy));
        beam.file("tau", 100);
        uint256 currentDSR = conv.rtob(dss.pot.dsr());

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange(DSR, currentDSR + 1);
        vm.prank(bud);
        beam.set(updates);

        vm.warp(block.timestamp + 99);

        updates[0] = SPBEAM.ParamChange(DSR, currentDSR + 2);
        vm.prank(bud);
        vm.expectRevert("SPBEAM/too-early");
        beam.set(updates);
    }

    function test_revert_set_malfunctioning_conv() public {
        bytes memory code = address(new MockBrokenConv()).code;
        vm.etch(address(conv), code);

        (uint256 duty,) = dss.jug.ilks(ILK);
        uint256 target = conv.rtob(duty) + 50;

        SPBEAM.ParamChange[] memory updates = new SPBEAM.ParamChange[](1);
        updates[0] = SPBEAM.ParamChange(ILK, target);

        vm.expectRevert("SPBEAM/invalid-rate-conv");
        vm.prank(bud);
        beam.set(updates);
    }
}
