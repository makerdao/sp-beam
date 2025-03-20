pragma solidity ^0.8.24;

import {DSPC} from "src/DSPC.sol";

contract DSPCHarness is DSPC {
    constructor(address _jug, address _pot, address _susds, address _conv) DSPC(_jug, _pot, _susds, _conv) {}

    function set(bytes32 id, uint256 bps) external {
        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0].id = id;
        updates[0].bps = bps;
        this.set(updates);
    }
}
