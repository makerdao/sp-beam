
pragma solidity ^0.8.24;

contract Conv {
    uint256 public constant MAX_BPS_IN = 50_00;
    uint256 internal constant RAY = 10 ** 27;
    uint256 internal constant BPS = 100_00;

    function btor(uint256 bps) external view returns (uint256 ray) {
        require(bps <= MAX_BPS_IN, "Conv/bps-too-high");

        // Deliberately wrong implementation
        return (bps * RAY + BPS / 2) / BPS / 365 days + RAY;
    }

    function rtob(uint256 ray) external pure returns (uint256 bps) {
        require(ray >= RAY, "Conv/ray-too-low");

        // Deliberately wrong implementation
        return ((ray - RAY) * BPS * 365 days + RAY/2) / RAY;
    }
}

