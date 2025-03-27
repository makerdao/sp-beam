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

interface ChiefLike {
    function hat() external view returns (address);
}

interface ConvLike {
    function turn(uint256 bps) external pure returns (uint256 ray);
    function back(uint256 ray) external pure returns (uint256 bps);
}

interface SUSDSLike {
    function ssr() external view returns (uint256);
    function drip() external;
}

interface ProxyLike {
    function exec(address usr, bytes memory fax) external returns (bytes memory out);
}

contract InitCaller {
    function init(DssInstance memory dss, SPBEAMInstance memory inst, SPBEAMConfig memory cfg) external {
        SPBEAMInit.init(dss, inst, cfg);
    }
}

contract SPBEAMMomIntegrationTest is DssTest {
    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    // --- Events ---
    event SetOwner(address indexed owner);
    event SetAuthority(address indexed authority);
    event Halt(address indexed spbeam);

    DssInstance dss;
    ChiefLike chief;
    SPBEAM spbeam;
    SPBEAMMom mom;
    ConvLike conv;
    SUSDSLike susds;
    address pause;
    ProxyLike pauseProxy;
    InitCaller caller;

    bytes32 constant ILK = "ETH-A";
    bytes32 constant DSR = "DSR";
    bytes32 constant SSR = "SSR";

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        chief = ChiefLike(dss.chainlog.getAddress("MCD_ADM"));
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
        spbeam = SPBEAM(inst.spbeam);
        mom = SPBEAMMom(inst.mom);

        // Initialize deployment
        SPBEAMConfig memory cfg = SPBEAMConfig({
            tau: 0, // Start with tau = 0 for tests
            ilks: new SPBEAMRateConfig[](0), // No ilks for this test
            bud: address(0) // No bud for this test
        });
        vm.prank(pause);
        pauseProxy.exec(address(caller), abi.encodeCall(caller.init, (dss, inst, cfg)));
    }

    function test_constructor() public view {
        assertEq(mom.owner(), address(pauseProxy));
    }

    function test_only_owner_methods() public {
        checkModifier(address(mom), "SPBEAMMom/not-owner", [SPBEAMMom.setOwner.selector, SPBEAMMom.setAuthority.selector]);
    }

    function test_auth_methods() public {
        checkModifier(address(mom), "SPBEAMMom/not-authorized", [SPBEAMMom.halt.selector]);

        vm.prank(address(pauseProxy));
        mom.setAuthority(address(0));
        checkModifier(address(mom), "SPBEAMMom/not-authorized", [SPBEAMMom.halt.selector]);
    }

    function test_setOwner() public {
        vm.prank(address(pauseProxy));
        vm.expectEmit(true, true, true, true);
        emit SetOwner(address(0x1234));
        mom.setOwner(address(0x1234));
        assertEq(mom.owner(), address(0x1234));
    }

    function test_setAuthority() public {
        vm.prank(address(pauseProxy));
        vm.expectEmit(true, true, true, true);
        emit SetAuthority(address(0x123));
        mom.setAuthority(address(0x123));
        assertEq(address(mom.authority()), address(0x123));
    }

    function check_halt(address who) internal {
        vm.prank(who);
        vm.expectEmit(true, true, true, true);
        emit Halt(address(spbeam));
        mom.halt(address(spbeam));
        assertEq(spbeam.bad(), 1);
    }

    function test_halt_owner() public {
        check_halt(address(pauseProxy));
    }

    function test_halt_hat() public {
        check_halt(chief.hat());
    }
}
