// SPDX-License-Identifier: MIT
// This contract limit amount ETH of each address can mint
pragma solidity ^0.8.19;

import "./support/IERC20.sol";
import "./support/SafeERC20.sol";
import "./support/ERC20.sol";
import "./support/utils/ReentrancyGuard.sol";
import "./fair-launch-uniswap-v2.sol";

contract LimitAmountFairLaunchToken is FairLaunchToken {
    using SafeERC20 for IERC20;

    uint256 public eachAddressLimitEthers;

    constructor(
        uint256 _price,
        uint256 _amountPerUnits,
        uint256 totalSupply,
        address _luncher,
        address _uniswapRouter,
        address _uniswapFactory,
        string memory _name,
        string memory _symbol,

        uint256 _eachAddressLimitEthers
    )
        FairLaunchToken(
            _price,
            _amountPerUnits,
            totalSupply,
            _luncher,
            _uniswapRouter,
            _uniswapFactory,
            _name,
            _symbol
        )
    {
        eachAddressLimitEthers = _eachAddressLimitEthers;
    }

    function mint() internal override nonReentrant {
        require(msg.value >= price, "FairMint: value not match");
        require(!_isContract(msg.sender), "FairMint: can not mint to contract");
        require(msg.sender == tx.origin, "FairMint: can not mint to contract.");
        // not start
        require(!started, "FairMint: already started");

        uint256 units = msg.value / price;
        uint256 realCost = units * price;
        uint256 refund = msg.value - realCost;

        require(
            minted + units * amountPerUnits <= mintLimit,
            "FairMint: exceed max supply"
        );

        require(
            balanceOf(msg.sender) * price / amountPerUnits  + realCost <= eachAddressLimitEthers,
            "FairMint: exceed max mint"
        );

        _transfer(address(this), msg.sender, units * amountPerUnits);
        minted += units * amountPerUnits;

        emit FairMinted(msg.sender, units * amountPerUnits, realCost);

        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
    }
}
// powered by WRB
// https://github.com/WhiteRiverBay/evm-fair-launch
