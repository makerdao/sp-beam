// SPDX-FileCopyrightText: 2025 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.24;

import "dss-test/DssTest.sol";
import {DSPC} from "../DSPC.sol";
import {DSPCMom} from "../DSPCMom.sol";
import {DSPCDeploy, DSPCDeployParams} from "./DSPCDeploy.sol";
import {DSPCInstance} from "./DSPCInstance.sol";
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

contract DSPCDeployTest is DssTest {
    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address susds;
    address deployer = address(0xDE9);
    address owner = address(0x123);

    DssInstance dss;
    ConvMock conv;
    DSPCInstance inst;

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        susds = dss.chainlog.getAddress("SUSDS");
        conv = new ConvMock();
    }

    function test_deploy() public {
        vm.startPrank(deployer);
        inst = DSPCDeploy.deploy(
            DSPCDeployParams({
                deployer: deployer,
                owner: owner,
                jug: address(dss.jug),
                pot: address(dss.pot),
                susds: susds,
                conv: address(conv)
            })
        );
        vm.stopPrank();

        // Verify DSPC deployment
        assertTrue(inst.dspc != address(0), "DSPC not deployed");
        assertEq(address(DSPC(inst.dspc).jug()), address(dss.jug), "Wrong jug");
        assertEq(address(DSPC(inst.dspc).pot()), address(dss.pot), "Wrong pot");
        assertEq(address(DSPC(inst.dspc).susds()), susds, "Wrong susds");
        assertEq(address(DSPC(inst.dspc).conv()), address(conv), "Wrong conv");

        // Verify DSPCMom deployment
        assertTrue(inst.mom != address(0), "DSPCMom not deployed");
        assertEq(DSPCMom(inst.mom).owner(), owner, "Wrong mom owner");

        // Verify ownership transfer
        assertEq(DSPC(inst.dspc).wards(owner), 1, "Owner not authorized in DSPC");
        assertEq(DSPC(inst.dspc).wards(deployer), 0, "Deployer still authorized in DSPC");
    }
}
