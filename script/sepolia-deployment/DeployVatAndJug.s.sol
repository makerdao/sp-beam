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
pragma solidity ^0.6.12;

import {Script, console} from "forge-std/Script.sol";
import { Vat } from "./Vat.sol";
import { Jug } from "./Jug.sol";


contract DeployVatAndJug is Script {

    address constant DSCPC = 0x4B5B12AC1bC588438Dcb08c28049e0956A589f0b;

    function run() external {
        vm.startBroadcast();

        Vat vat = new Vat();
        Jug jug = new Jug(address(vat));

        console.log("Vat deployed at", address(vat));
        console.log("Jug deployed at", address(jug));

        vat.rely(address(jug));

        vat.init("ETH-A");
        jug.init("ETH-A");

        vat.init("ETH-B");
        jug.init("ETH-B");

        vat.init("ETH-C");
        jug.init("ETH-C");

        vat.rely(DSCPC);
        jug.rely(DSCPC);

        vm.stopBroadcast();
    }


}
