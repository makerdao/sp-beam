// DSPC.spec

using Conv as conv;
using Jug as jug;
using Pot as pot;
using ERC1967Proxy as susds;
using SUsds as susdsImp;
using Vat as vat;

methods {
    function RAY() external returns (uint256) envfree;
    function bad() external returns (uint8) envfree;
    function buds(address) external returns (uint256) envfree;
    function cfgs(bytes32) external returns (uint16, uint16, uint16) envfree;
    function tau() external returns (uint64) envfree;
    function toc() external returns (uint128) envfree;
    function wards(address) external returns (uint256) envfree;

    function conv.rtob(uint256) external returns (uint256) envfree;
    function conv.btor(uint256) external returns (uint256) envfree;
    function conv.MAX_BPS_IN() external returns (uint256) envfree;

    function jug.ilks(bytes32) external returns (uint256, uint256) envfree;

    function pot.dsr() external returns (uint256) envfree;

    function susdsImp.ssr() external returns (uint256) envfree;

    function vat.live() external returns (uint256) envfree;
    function vat.can(address, address) external returns (uint256) envfree;
    function vat.dai(address) external returns (uint256) envfree;
    function vat.debt() external returns (uint256) envfree;
    function vat.Line() external returns (uint256) envfree;
    function vat.ilks(bytes32) external returns (uint256, uint256, uint256, uint256, uint256) envfree;
    function vat.urns(bytes32, address) external returns (uint256, uint256) envfree;
}

definition TAU() returns bytes32 = to_bytes32(0x7461750000000000000000000000000000000000000000000000000000000000);
definition TOC() returns bytes32 = to_bytes32(0x746f630000000000000000000000000000000000000000000000000000000000);
definition BAD() returns bytes32 = to_bytes32(0x6261640000000000000000000000000000000000000000000000000000000000);
definition MIN() returns bytes32 = to_bytes32(0x6d696e0000000000000000000000000000000000000000000000000000000000);
definition MAX() returns bytes32 = to_bytes32(0x6d61780000000000000000000000000000000000000000000000000000000000);
definition STEP() returns bytes32 = to_bytes32(0x7374657000000000000000000000000000000000000000000000000000000000);
definition SSR() returns bytes32 = to_bytes32(0x5353520000000000000000000000000000000000000000000000000000000000);
definition DSR() returns bytes32 = to_bytes32(0x4453520000000000000000000000000000000000000000000000000000000000);

// Verify that each storage variable is only modified in the expected functions
rule storage_affected(method f) {
    env e;
    address anyAddr;
    bytes32 anyId;

    mathint wardsBefore = wards(anyAddr);
    mathint budsBefore = buds(anyAddr);
    mathint minBefore; mathint maxBefore; mathint stepBefore;
    minBefore, maxBefore, stepBefore = cfgs(anyId);
    mathint badBefore = bad();
    mathint tauBefore = tau();
    mathint tocBefore = toc();

    calldataarg args;
    f(e, args);

    mathint wardsAfter = wards(anyAddr);
    mathint budsAfter = buds(anyAddr);
    mathint minAfter; mathint maxAfter; mathint stepAfter;
    minAfter, maxAfter, stepAfter = cfgs(anyId);
    mathint badAfter = bad();
    mathint tauAfter = tau();
    mathint tocAfter = toc();


    assert wardsAfter != wardsBefore => f.selector == sig:rely(address).selector || f.selector == sig:deny(address).selector, "wards[x] changed in an unexpected function";
    assert budsAfter != budsBefore => f.selector == sig:kiss(address).selector || f.selector == sig:diss(address).selector, "buds[x] changed in an unexpected function";
    assert minAfter != minBefore => f.selector == sig:file(bytes32, bytes32, uint256).selector, "min[x] changed in an unexpected function";
    assert maxAfter != maxBefore => f.selector == sig:file(bytes32, bytes32, uint256).selector, "max[x] changed in an unexpected function";
    assert stepAfter != stepBefore => f.selector == sig:file(bytes32, bytes32, uint256).selector, "step[x] changed in an unexpected function";
    assert badAfter != badBefore => f.selector == sig:file(bytes32, uint256).selector, "bad[x] changed in an unexpected function";
    assert tauAfter != tauBefore => f.selector == sig:file(bytes32, uint256).selector, "tau changed in an unexpected function";
    assert tocAfter != tocBefore => f.selector == sig:file(bytes32, uint256).selector || f.selector == sig:set(bytes32, uint256).selector, "toc changed in an unexpected function";
}

// Verify that the correct storage changes for non-reverting rely
rule rely(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    rely(e, usr);

    mathint wardsOtherAfter = wards(other);
    mathint wardsUsrAfter = wards(usr);

    assert wardsUsrAfter == 1, "rely did not set wards[usr]";
    assert wardsOtherAfter == wardsOtherBefore, "rely unexpectedly changed other wards[x]";
}

// Verify revert rules on rely
rule rely_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    rely@withrevert(e, usr);

    assert lastReverted <=> revert1 || revert2, "rely revert rules failed";
}

// Verify that the correct storage changes for non-reverting deny
rule deny(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    deny(e, usr);

    mathint wardsOtherAfter = wards(other);
    mathint wardsUsrAfter = wards(usr);

    assert wardsUsrAfter == 0, "deny did not set wards[usr]";
    assert wardsOtherAfter == wardsOtherBefore, "deny unexpectedly changed other wards[x]";
}

// Verify revert rules on deny
rule deny_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    deny@withrevert(e, usr);

    assert lastReverted <=> revert1 || revert2, "deny revert rules failed";
}

// Verify that the correct storage changes for non-reverting kiss
rule kiss(address usr) {
    env e;

    address other;
    require other != usr;

    mathint budsOtherBefore = buds(other);

    kiss(e, usr);

    mathint budsOtherAfter = buds(other);
    mathint budsUsrAfter = buds(usr);

    assert budsUsrAfter == 1, "kiss did not set buds[usr]";
    assert budsOtherAfter == budsOtherBefore, "kiss unexpectedly changed other buds[x]";
}

// Verify revert rules on kiss
rule kiss_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    kiss@withrevert(e, usr);

    assert lastReverted <=> revert1 || revert2, "kiss revert rules failed";
}

// Verify that the correct storage changes for non-reverting diss
rule diss(address usr) {
    env e;

    address other;
    require other != usr;

    mathint budsOtherBefore = buds(other);

    diss(e, usr);

    mathint budsOtherAfter = buds(other);
    mathint budsUsrAfter = buds(usr);

    assert budsUsrAfter == 0, "diss did not set buds[usr]";
    assert budsOtherAfter == budsOtherBefore, "diss unexpectedly changed other buds[x]";
}

// Verify revert rules on diss
rule diss_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    diss@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "diss revert rules failed";
}

// Verify correct storage changes for non-reverting file for global parameters
rule file_global(bytes32 what, uint256 data) {
    env e;

    mathint badBefore = bad();
    mathint tauBefore = tau();
    mathint tocBefore = toc();

    file(e, what, data);

    mathint badAfter = bad();
    mathint tauAfter = tau();
    mathint tocAfter = toc();

    assert what == BAD() => badAfter == to_mathint(data), "file did not set bad";
    assert what != BAD() => badAfter == badBefore, "file did keep unchanged bad";
    assert what == TAU() => tauAfter == to_mathint(data), "file did not set tau";
    assert what != TAU() => tauAfter == tauBefore, "file did keep unchanged tau";
    assert what == TOC() => tocAfter == to_mathint(data), "file did not set toc";
    assert what != TOC() => tocAfter == tocBefore, "file did keep unchanged toc";
}

// Verify revert rules on file for global parameters
rule file_global_revert(bytes32 what, uint256 data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = what != BAD() && what != TAU() && what != TOC();
    bool revert4 = what == BAD() && to_mathint(data) != 0 && to_mathint(data) != 1;
    bool revert5 = what == TAU() && to_mathint(data) > max_uint64;
    bool revert6 = what == TOC() && to_mathint(data) > max_uint128;

    file@withrevert(e, what, data);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6,
                            "file revert rules failed";
}

// Verify correct storage changes for non-reverting file for individual rate parameters
rule file_per_id(bytes32 id, bytes32 what, uint256 data) {
    env e;

    mathint minBefore; mathint maxBefore; mathint stepBefore;
    minBefore, maxBefore, stepBefore = cfgs(id);

    file(e, id, what, data);

    mathint minAfter; mathint maxAfter; mathint stepAfter;
    minAfter, maxAfter, stepAfter = cfgs(id);

    assert what == MIN() => minAfter == to_mathint(data), "file did not set min";
    assert what != MIN() => minAfter == minBefore, "file did keep unchanged min";
    assert what == MAX() => maxAfter == to_mathint(data), "file did not set max";
    assert what != MAX() => maxAfter == maxBefore, "file did keep unchanged max";
    assert what == STEP() => stepAfter == to_mathint(data), "file did not set step";
    assert what != STEP() => stepAfter == stepBefore, "file did keep unchanged step";
}

// Verify revert rules on file for individual rate parameters
rule file_per_id_revert(bytes32 id, bytes32 what, uint256 data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);
    mathint minBefore; mathint maxBefore; mathint stepBefore;
    minBefore, maxBefore, stepBefore = cfgs(id);
    mathint duty; mathint _rate;
    duty, _rate = jug.ilks(id);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = id != DSR() && id != SSR() && duty == 0;
    bool revert4 = what != MIN() && what != MAX() && what != STEP();
    bool revert5 = to_mathint(data) > max_uint16;
    bool revert6 = what == MIN() && to_mathint(data) > maxBefore;
    bool revert7 = what == MAX() && to_mathint(data) < minBefore;

    file@withrevert(e, id, what, data);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7,
                            "file revert rules failed";
}

// Verify correct storage changes for non-reverting set for a single rate.
rule set_single(bytes32 id, uint256 bps) {
    env e;
    bytes32 ilk;
    require ilk != DSR() && ilk != SSR();

    mathint ray = conv.btor(bps);

    mathint dsrBefore = pot.dsr();
    mathint ssrBefore = susdsImp.ssr();
    mathint dutyBefore; mathint _rho;
    dutyBefore, _rho = jug.ilks(ilk);

    set(e, id, bps);

    mathint dsrAfter = pot.dsr();
    mathint ssrAfter = susdsImp.ssr();
    mathint dutyAfter;
    dutyAfter, _rho = jug.ilks(ilk);

    assert id == DSR() => dsrAfter == ray, "set did not set dsr";
    assert id != DSR() => dsrAfter == dsrBefore, "set did keep unchanged dsr";

    assert id == SSR() => ssrAfter == ray, "set did not set ssr";
    assert id != SSR() => ssrAfter == ssrBefore, "set did keep unchanged ssr";

    assert id == ilk => dutyAfter == ray, "set did not set duty";
    assert id != ilk => dutyAfter == dutyBefore, "set did keep unchanged duty";
}

// Verify revert rules for set for a single rate
rule set_single_revert(bytes32 id, uint256 bps) {
    env e;

    mathint tau = tau();
    mathint toc = toc();
    mathint min; mathint max; mathint step;
    min, max, step = cfgs(id);

    mathint oldBps;
    if (id == DSR()) {
        oldBps = conv.rtob(pot.dsr());
    } else if (id == SSR()) {
        oldBps = conv.rtob(susdsImp.ssr());
    } else {
        uint256 duty; mathint _rate;
        duty, _rate = jug.ilks(id);
        oldBps = conv.rtob(duty);
    }

    // We need a second variable because it's not possible to reassign variables in CVL
    mathint actualOldBps;
    if (oldBps < min) {
        actualOldBps = min;
    } else if (oldBps > max) {
        actualOldBps = max;
    } else {
        actualOldBps = oldBps;
    }

    mathint delta = bps > actualOldBps ? bps - actualOldBps : actualOldBps - bps;
    mathint ray = conv.btor(bps);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.block.timestamp < tau + toc;
    bool revert3 = step == 0;
    bool revert4 = to_mathint(bps) > max;
    bool revert5 = to_mathint(bps) < min;
    bool revert6 = delta > step;
    bool revert7 = ray < RAY();

    set@withrevert(e, id, bps);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7,
                            "set revert rules failed";
}
