// SPDX-FileCopyrightText: © 2025 Dai Foundation <www.daifoundation.org>
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

import {Script, console} from "forge-std/Script.sol";
import { ConvMock } from "../../src/mocks/ConvMock.sol";
import { DSPC } from "../../src/DSPC.sol";



contract DSPCDeployScriptToSepolia is Script {

    address SENDER = 0x195a7d8610edd06e0C27c006b6970319133Cb19A;

    address constant VAT = 0xE938502439f4a4bdA4C7D6484c8B6b22C9Cd0042;
    address constant JUG = 0xc62B866a8faA6AEff8B73d55B6F73B64b74e4fAd;

    function run() external {
        vm.startBroadcast();

        ConvMock conv = new ConvMock();
        console.log("convMock", address(conv));

        DSPC dspc = new DSPC(JUG, address(0), address(0), address(conv));
        console.log("dspc", address(dspc));

        dspc.file("tau", 1 hours);

        dspc.file(bytes32("ETH-A"), "max", uint256(30000));
        dspc.file(bytes32("ETH-A"), "min", uint256(1));
        dspc.file(bytes32("ETH-A"), "step", uint256(100));

        dspc.file(bytes32("ETH-B"), "max", uint256(30000));
        dspc.file(bytes32("ETH-B"), "min", uint256(1));
        dspc.file(bytes32("ETH-B"), "step", uint256(100));

        dspc.file(bytes32("ETH-C"), "max", uint256(30000));
        dspc.file(bytes32("ETH-C"), "min", uint256(1));
        dspc.file(bytes32("ETH-C"), "step", uint256(100));

        // Authorize bud
        dspc.kiss(SENDER);

        // Try changing a rate
        uint256 ethATarget = 20;
        uint256 ethBTarget = 50;
        uint256 ethCTarget = 100;

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](3);
        updates[0] = DSPC.ParamChange(bytes32("ETH-A"), ethATarget);
        updates[1] = DSPC.ParamChange(bytes32("ETH-B"), ethBTarget);
        updates[2] = DSPC.ParamChange(bytes32("ETH-C"), ethCTarget);

        dspc.set(updates);

        vm.stopBroadcast();
    }


}

