// SPBEAM.spec

using SPBEAM as spbeam;
using Conv as conv;
using Jug as jug;
using Pot as pot;
using SUsds as susds;
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
    function jug.wards(address) external returns (uint256) envfree;

    function pot.dsr() external returns (uint256) envfree;
    function pot.rho() external returns (uint256) envfree;
    function pot.wards(address) external returns (uint256) envfree;

    function susds.ssr() external returns (uint256) envfree;
    function susds.rho() external returns (uint256) envfree;
    function susds.wards(address) external returns (uint256) envfree;

    function vat.Line() external returns (uint256) envfree;
    function vat.can(address, address) external returns (uint256) envfree;
    function vat.dai(address) external returns (uint256) envfree;
    function vat.debt() external returns (uint256) envfree;
    function vat.ilks(bytes32) external returns (uint256, uint256, uint256, uint256, uint256) envfree;
    function vat.live() external returns (uint256) envfree;
    function vat.urns(bytes32, address) external returns (uint256, uint256) envfree;
}

definition EMPTY_BYTES32() returns bytes32 = to_bytes32(0x0000000000000000000000000000000000000000000000000000000000000000);
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
    assert badAfter != badBefore => f.selector == sig:file(bytes32, uint256).selector, "bad changed in an unexpected function";
    assert tauAfter != tauBefore => f.selector == sig:file(bytes32, uint256).selector, "tau changed in an unexpected function";
    assert tocAfter != tocBefore => f.selector == sig:file(bytes32, uint256).selector || f.selector == sig:set(SPBEAM.ParamChange[] calldata).selector, "toc changed in an unexpected function";
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

    assert lastReverted <=>
        revert1 || revert2 || revert3 ||
        revert4 || revert5 || revert6,
        "file revert rules failed";
}

// Verify correct storage changes for non-reverting file for individual rate parameters
rule file_per_id(bytes32 id, bytes32 what, uint256 data) {
    env e;
    bytes32 other;
    require other != id;

    mathint minBefore; mathint maxBefore; mathint stepBefore;
    minBefore, maxBefore, stepBefore = cfgs(id);

    mathint minOtherBefore; mathint maxOtherBefore; mathint stepOtherBefore;
    minOtherBefore, maxOtherBefore, stepOtherBefore = cfgs(other);

    file(e, id, what, data);

    mathint minAfter; mathint maxAfter; mathint stepAfter;
    minAfter, maxAfter, stepAfter = cfgs(id);

    assert what == MIN() => minAfter == to_mathint(data), "file did not set min";
    assert what != MIN() => minAfter == minBefore, "file did keep unchanged min";
    assert what == MAX() => maxAfter == to_mathint(data), "file did not set max";
    assert what != MAX() => maxAfter == maxBefore, "file did keep unchanged max";
    assert what == STEP() => stepAfter == to_mathint(data), "file did not set step";
    assert what != STEP() => stepAfter == stepBefore, "file did keep unchanged step";

    mathint minOtherAfter; mathint maxOtherAfter; mathint stepOtherAfter;
    minOtherAfter, maxOtherAfter, stepOtherAfter = cfgs(other);

    assert minOtherAfter == minOtherBefore, "file unexpectedly changed other min";
    assert maxOtherAfter == maxOtherBefore, "file unexpectedly changed other max";
    assert stepOtherAfter == stepOtherBefore, "file unexpectedly changed other step";
}

// Verify revert rules on file for individual rate parameters
rule file_per_id_revert(bytes32 id, bytes32 what, uint256 data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);
    mathint minBefore; mathint maxBefore; mathint stepBefore;
    minBefore, maxBefore, stepBefore = cfgs(id);
    mathint duty; mathint _rho;
    duty, _rho = jug.ilks(id);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = id != DSR() && id != SSR() && duty == 0;
    bool revert4 = what != MIN() && what != MAX() && what != STEP();
    bool revert5 = to_mathint(data) > max_uint16;
    bool revert6 = what == MIN() && to_mathint(data) > maxBefore;
    bool revert7 = what == MAX() && to_mathint(data) < minBefore;

    file@withrevert(e, id, what, data);

    assert lastReverted <=>
        revert1 || revert2 || revert3 ||
        revert4 || revert5 || revert6 ||
        revert7,
        "file revert rules failed";
}

ghost mapping(mathint => mathint) bps_to_ray {
    init_state axiom forall mathint i. bps_to_ray[i] == 0;
}

// Verify correct storage changes for non-reverting set
rule set(SPBEAM.ParamChange[] updates) {
    env e;
    bytes32 ilk;
    require ilk != DSR() && ilk != SSR();
    require updates.length < 4;

    mathint dsrBefore = pot.dsr();
    mathint ssrBefore = susds.ssr();
    mathint dutyBefore; mathint _rho;
    dutyBefore, _rho = jug.ilks(ilk);

    set(e, updates);

    mathint dsrAfter = pot.dsr();
    mathint ssrAfter = susds.ssr();
    mathint dutyAfter;
    dutyAfter, _rho = jug.ilks(ilk);

    // Manually convert all BPS values to RAY after the function call
    // Store in the ghost mapping to use it in the assertions
    if (updates.length > 0) {
        bps_to_ray[updates[0].bps] = conv.btor(updates[0].bps);
    }
    if (updates.length > 1) {
        bps_to_ray[updates[1].bps] = conv.btor(updates[1].bps);
    }
    if (updates.length > 2) {
        bps_to_ray[updates[2].bps] = conv.btor(updates[2].bps);
    }

    // If DSR is in updates, then its value should match the converted input value
    assert exists uint256 i. i < updates.length && updates[i].id == DSR() =>
        dsrAfter == bps_to_ray[updates[i].bps], "DSR in updates; dsr not set correctly";
    // If DSR is not in updates, then the value should not change
    assert (forall uint256 i. i < updates.length => updates[i].id != DSR()) =>
        dsrAfter == dsrBefore, "DSR not in updates; dsr changed unexpectedly";
    // If the value of DSR changed, then it should be in updates
    assert dsrAfter != dsrBefore =>
        (exists uint256 i. i < updates.length && updates[i].id == DSR()), "dsr changed; DSR not in updates";
    // If the value of DSR did not change, then it should either NOT be in updates or be in updates with the same value
    assert dsrAfter == dsrBefore => (
        (forall uint256 i. i < updates.length => updates[i].id != DSR()) ||
        (exists uint256 i. i < updates.length && updates[i].id == DSR() && bps_to_ray[updates[i].bps] == dsrBefore)
    ), "dsr not changed; DSR in updates with different value";

    // If SSR is in updates, then its value should match the converted input value
    assert exists uint256 i. i < updates.length && updates[i].id == SSR() =>
        ssrAfter == bps_to_ray[updates[i].bps], "SSR in updates; ssr not set correctly";
    // If SSR is not in updates, then the value should not change
    assert (forall uint256 i. i < updates.length => updates[i].id != SSR()) =>
        ssrAfter == ssrBefore, "SSR not in updates; ssr changed unexpectedly";
    // If the value of SSR changed, then it should be in updates
    assert ssrAfter != ssrBefore => (
        exists uint256 i. i < updates.length && updates[i].id == SSR()
    ), "ssr changed; SSR not in updates";
    // If the value of SSR did not change, then it should either NOT be in updates or be in updates with the same value
    assert ssrAfter == ssrBefore => (
        (forall uint256 i. i < updates.length => updates[i].id != SSR()) ||
        (exists uint256 i. i < updates.length && updates[i].id == SSR() && bps_to_ray[updates[i].bps] == ssrBefore)
    ), "ssr not changed; SSR in updates with different value";

    // If ilk is in updates, then its duty value should match the converted input value
    assert exists uint256 i. i < updates.length && updates[i].id == ilk =>
        dutyAfter == bps_to_ray[updates[i].bps], "ilk in updates; duty not set correctly";
    // If ilk is not in updates, then the value should not change
    assert (forall uint256 i. i < updates.length => updates[i].id != ilk) =>
        dutyAfter == dutyBefore, "ilk not in updates; duty changed unexpectedly";
    // If the value of ilk duty changed, then it should be in updates
    assert dutyAfter != dutyBefore =>
        (exists uint256 i. i < updates.length && updates[i].id == ilk), "duty changed; ilk not in updates";
    // If the value of ilk duty did not change, then it should either NOT be in updates or be in updates with the same value
    assert dutyAfter == dutyBefore => (
        (forall uint256 i. i < updates.length => updates[i].id != ilk) ||
        (exists uint256 i. i < updates.length && updates[i].id == ilk && bps_to_ray[updates[i].bps] == dutyBefore)
    ), "duty not changed; ilk in updates with different value";
}

ghost mapping(bytes32 => bool) set_item_reverted {
    init_state axiom forall bytes32 i. set_item_reverted[i] == false;
}

rule set_revert(SPBEAM.ParamChange[] updates, uint256[] idsAsUints, uint256[] bpss) {
    env e;
    bytes32 ilk;

    require ilk != DSR() && ilk != SSR();
    require updates.length < 4;
    require updates.length == bpss.length;
    require idsAsUints.length == bpss.length;
    // ID cannot be bytes32(0)
    require forall uint256 i. i < updates.length => (
        updates[i].id != EMPTY_BYTES32() &&
            updates[i].id == to_bytes32(idsAsUints[i]) &&
            updates[i].bps == to_mathint(bpss[i])
    );
    // It is impossible for `toc` to be greater than block.timestamp
    require toc() <= e.block.timestamp;
    // Required because `toc` is a `uint128` and `toc = block.timestamp` in the implementation
    require e.block.timestamp <= max_uint128;

    bool revert1 = e.msg.value > 0;
    bool revert2 = buds(e.msg.sender) != 1;
    bool revert3 = bad() != 0;
    bool revert4 = e.block.timestamp < tau() + toc();
    // No updates
    bool revert5 = updates.length == 0;
    // Strictly ordered elements
    bool revert6 = idsAsUints.length == 2 ? idsAsUints[0] >= idsAsUints[1] : false;
    bool revert7 = idsAsUints.length == 3 ? (
        idsAsUints[0] >= idsAsUints[1] ||
        idsAsUints[0] >= idsAsUints[2] ||
        idsAsUints[1] >= idsAsUints[2]
    ) : false;

    if (updates.length > 0) {
        set_item_reverted[updates[0].id] = check_item_revert(e, updates[0].id, updates[0].bps);
    }
    if (updates.length > 1) {
        set_item_reverted[updates[1].id] = check_item_revert(e, updates[1].id, updates[1].bps);
    }
    if (updates.length > 2) {
        set_item_reverted[updates[2].id] = check_item_revert(e, updates[2].id, updates[2].bps);
    }

    bool revert8 = exists uint256 i. i < updates.length && set_item_reverted[updates[i].id];

    set@withrevert(e, updates);

    assert lastReverted =>
        revert1 || revert2 || revert3 ||
        revert4 || revert5 || revert6 ||
        revert7 || revert8,
        "set reverted for an unknown reason";

    assert revert1 || revert2 || revert3 ||
        revert4 || revert5 || revert6 ||
        revert7 || revert8 =>
        lastReverted,
        "set should have reverted";
}

function check_item_revert(env e, bytes32 id, uint256 bps) returns bool {
    mathint min; mathint max; mathint step;
    min, max, step = cfgs(id);

    // min <= max is enforced in the implementation
    require min <= max;

    mathint oldBps;
    if (id == DSR()) {
        // IF block.timestamp < rho, drip will revert
        require(e.block.timestamp >= pot.rho());
        oldBps = conv.rtob(pot.dsr());
    } else if (id == SSR()) {
        // IF block.timestamp <= rho, drip will not update rho and file will revert
        require(e.block.timestamp > pot.rho());
        oldBps = conv.rtob(susds.ssr());
    } else {
        uint256 duty; mathint rho;
        duty, rho = jug.ilks(id);
        // IF rho >= block.timestamp, drip will revert
        require(e.block.timestamp >= rho);
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

    bool revertA = step == 0;
    bool revertB = to_mathint(bps) > max;
    bool revertC = to_mathint(bps) < min;
    bool revertD = delta > step;
    bool revertE = ray < RAY();
    bool revertF = bps > conv.MAX_BPS_IN();
    bool revertG = id == DSR() && pot.wards(currentContract) != 1;
    bool revertH = id == SSR() && susds.wards(currentContract) != 1;
    bool revertI = id != DSR() && id != SSR() && jug.wards(currentContract) != 1;

    return
        revertA  || revertB || revertC ||
        revertD  || revertE || revertF ||
        revertG  || revertH || revertI;

}

rule set_current_higher_than_max(SPBEAM.ParamChange[] updates) {
    env e;

    require updates.length == 1;
    bytes32 id = updates[0].id;
    uint256 bps = updates[0].bps;

    bytes32 ilk;
    require ilk != DSR() && ilk != SSR();

    uint256 min; uint256 max; uint256 step;
    min, max, step = cfgs(id);
    require bps >= min && bps <= max;
    bps_to_ray[bps] = conv.btor(bps);
    bps_to_ray[max] = conv.btor(max);

    uint256 dsrBefore = pot.dsr();
    uint256 ssrBefore = susds.ssr();
    uint256 dutyBefore; mathint _rho;
    dutyBefore, _rho = jug.ilks(ilk);

    require id == DSR() => dsrBefore > bps_to_ray[max];
    require id == SSR() => ssrBefore > bps_to_ray[max];
    require id != DSR() && id != SSR() => dutyBefore > bps_to_ray[max];

    set(e, updates);

    uint256 dsrAfter = pot.dsr();
    uint256 ssrAfter = susds.ssr();
    uint256 dutyAfter;
    dutyAfter, _rho = jug.ilks(ilk);

    assert id == DSR() => dsrAfter  == bps_to_ray[bps] && bps >= max - step && bps <= max, "dsr not within bounds";
    assert id == SSR() => ssrAfter  == bps_to_ray[bps] && bps >= max - step && bps <= max, "ssr not within bounds";
    assert id == ilk   => dutyAfter == bps_to_ray[bps] && bps >= max - step && bps <= max, "ilk duty not within bounds";
}

rule set_current_lower_than_min(SPBEAM.ParamChange[] updates) {
    env e;

    require updates.length == 1;
    bytes32 id = updates[0].id;
    uint256 bps = updates[0].bps;

    bytes32 ilk;
    require ilk != DSR() && ilk != SSR();

    uint256 min; uint256 max; uint256 step;
    min, max, step = cfgs(id);
    require bps >= min && bps <= max;
    bps_to_ray[bps] = conv.btor(bps);
    bps_to_ray[min] = conv.btor(min);

    uint256 dsrBefore = pot.dsr();
    uint256 ssrBefore = susds.ssr();
    uint256 dutyBefore; mathint _rho;
    dutyBefore, _rho = jug.ilks(ilk);

    require id == DSR() => dsrBefore < bps_to_ray[min];
    require id == SSR() => ssrBefore < bps_to_ray[min];
    require id != DSR() && id != SSR() => dutyBefore < bps_to_ray[min];

    set(e, updates);

    uint256 dsrAfter = pot.dsr();
    uint256 ssrAfter = susds.ssr();
    uint256 dutyAfter;
    dutyAfter, _rho = jug.ilks(ilk);

    assert id == DSR() => dsrAfter  == bps_to_ray[bps] && bps >= min && bps <= min + step, "dsr not within bounds";
    assert id == SSR() => ssrAfter  == bps_to_ray[bps] && bps >= min && bps <= min + step, "ssr not within bounds";
    assert id == ilk   => dutyAfter == bps_to_ray[bps] && bps >= min && bps <= min + step, "ilk duty not within bounds";
}
