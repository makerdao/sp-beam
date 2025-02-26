// SPDX-FileCopyrightText: 2025 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.24;

import "dss-test/DssTest.sol";
import {DSPC} from "../DSPC.sol";
import {DSPCMom} from "../DSPCMom.sol";
import {DSPCDeploy, DSPCDeployParams} from "./DSPCDeploy.sol";
import {DSPCInit} from "./DSPCInit.sol";
import {DSPCInstance} from "./DSPCInstance.sol";
import {ConvMock} from "../mocks/ConvMock.sol";

interface RelyLike {
    function rely(address usr) external;
}

interface JugLike is RelyLike {
    function wards(address) external view returns (uint256);
}

interface PotLike is RelyLike {
    function wards(address) external view returns (uint256);
}

interface SUSDSLike is RelyLike {
    function wards(address) external view returns (uint256);
}

interface ProxyLike {
    function exec(address usr, bytes memory fax) external returns (bytes memory out);
}

contract InitCaller {
    function init(DssInstance memory dss, DSPCInstance memory inst) external {
        DSPCInit.init(dss, inst);
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
        vm.prank(pause);
        pauseProxy.exec(address(caller), abi.encodeCall(caller.init, (dss, inst)));

        // Verify DSPCMom authority
        assertEq(DSPCMom(inst.mom).authority(), dss.chainlog.getAddress("MCD_ADM"), "Wrong authority");

        // Verify DSPC permissions
        assertEq(DSPC(inst.dspc).wards(inst.mom), 1, "Mom not authorized in DSPC");

        // Verify core contract permissions
        assertEq(JugLike(address(dss.jug)).wards(inst.dspc), 1, "DSPC not authorized in Jug");
        assertEq(PotLike(address(dss.pot)).wards(inst.dspc), 1, "DSPC not authorized in Pot");
        assertEq(SUSDSLike(susds).wards(inst.dspc), 1, "DSPC not authorized in SUSDS");
    }
}
