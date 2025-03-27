pragma solidity ^0.8.24;

import "src/DSPC.sol";

contract DSPCHarness is DSPC {
    constructor(address _jug, address _pot, address _susds, address _conv) DSPC(_jug, _pot, _susds, _conv) {}

    function set(bytes32 id, uint256 bps) external toll good {
        Cfg memory cfg = cfgs[id];

        require(cfg.step > 0, "DSPC/rate-not-configured");
        require(bps >= cfg.min, "DSPC/below-min");
        require(bps <= cfg.max, "DSPC/above-max");

        // Check rate change is within allowed gap
        uint256 oldBps;
        if (id == "DSR") {
            oldBps = conv.rtob(PotLike(pot).dsr());
        } else if (id == "SSR") {
            oldBps = conv.rtob(SUSDSLike(susds).ssr());
        } else {
            (uint256 duty,) = JugLike(jug).ilks(id);
            oldBps = conv.rtob(duty);
        }

        if (oldBps < cfg.min) {
            oldBps = cfg.min;
        } else if (oldBps > cfg.max) {
            oldBps = cfg.max;
        }

        // Calculates absolute difference between the old and the new rate
        uint256 delta = bps > oldBps ? bps - oldBps : oldBps - bps;
        require(delta <= cfg.step, "DSPC/delta-above-step");

        // Execute the update
        uint256 ray = conv.btor(bps);
        require(ray >= RAY, "DSPC/invalid-rate-conv");
        if (id == "DSR") {
            pot.drip();
            pot.file("dsr", ray);
        } else if (id == "SSR") {
            susds.drip();
            susds.file("ssr", ray);
        } else {
            jug.drip(id);
            jug.file(id, "duty", ray);
        }
        emit Set(id, bps);
    }
}
