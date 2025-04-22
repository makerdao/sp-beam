// SPDX-FileCopyrightText: 2025 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.24;

import "dss-test/DssTest.sol";
import {SPBEAM} from "../SPBEAM.sol";
import {SPBEAMMom} from "../SPBEAMMom.sol";
import {SPBEAMDeploy, SPBEAMDeployParams} from "./SPBEAMDeploy.sol";
import {SPBEAMInstance} from "./SPBEAMInstance.sol";
import {ConvMock} from "../mocks/ConvMock.sol";

interface JugLike {
    function wards(address) external view returns (uint256);
}

interface PotLike {
    function wards(address) external view returns (uint256);
}

interface SUSDSLike {
    function wards(address) external view returns (uint256);
}

contract SPBEAMDeployTest is DssTest {
    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address susds;
    address deployer = address(0xDE9);
    address owner = address(0x123);

    DssInstance dss;
    ConvMock conv;
    SPBEAMInstance inst;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        susds = dss.chainlog.getAddress("SUSDS");
        conv = new ConvMock();
    }

    function test_deploy() public {
        vm.startPrank(deployer);
        inst = SPBEAMDeploy.deploy(
            SPBEAMDeployParams({
                deployer: deployer,
                owner: owner,
                jug: address(dss.jug),
                pot: address(dss.pot),
                susds: susds,
                conv: address(conv)
            })
        );
        vm.stopPrank();

        // Verify SPBEAM deployment
        assertTrue(inst.spbeam != address(0), "SPBEAM not deployed");
        assertEq(address(SPBEAM(inst.spbeam).jug()), address(dss.jug), "Wrong jug");
        assertEq(address(SPBEAM(inst.spbeam).pot()), address(dss.pot), "Wrong pot");
        assertEq(address(SPBEAM(inst.spbeam).susds()), susds, "Wrong susds");
        assertEq(address(SPBEAM(inst.spbeam).conv()), address(conv), "Wrong conv");

        // Verify SPBEAMMom deployment
        assertTrue(inst.mom != address(0), "SPBEAMMom not deployed");
        assertEq(SPBEAMMom(inst.mom).owner(), owner, "Wrong mom owner");

        // Verify ownership transfer
        assertEq(SPBEAM(inst.spbeam).wards(owner), 1, "Owner not authorized in SPBEAM");
        assertEq(SPBEAM(inst.spbeam).wards(deployer), 0, "Deployer still authorized in SPBEAM");
    }
}
