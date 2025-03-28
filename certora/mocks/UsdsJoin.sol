// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

interface UsdsLike {
    function burn(address, uint256) external;
    function mint(address, uint256) external;
}

interface VatLike {
    function move(address, address, uint256) external;
}

contract UsdsJoin {
    VatLike public immutable vat; // CDP Engine
    UsdsLike public immutable usds; // Stablecoin Token

    uint256 constant RAY = 10 ** 27;

    // --- Events ---
    event Join(address indexed caller, address indexed usr, uint256 wad);
    event Exit(address indexed caller, address indexed usr, uint256 wad);

    constructor(address vat_, address usds_) {
        vat = VatLike(vat_);
        usds = UsdsLike(usds_);
    }

    function join(address usr, uint256 wad) external {
        vat.move(address(this), usr, RAY * wad);
        usds.burn(msg.sender, wad);
        emit Join(msg.sender, usr, wad);
    }

    function exit(address usr, uint256 wad) external {
        vat.move(msg.sender, address(this), RAY * wad);
        usds.mint(usr, wad);
        emit Exit(msg.sender, usr, wad);
    }

    // To fully cover daiJoin abi
    function dai() external view returns (address) {
        return address(usds);
    }
}
