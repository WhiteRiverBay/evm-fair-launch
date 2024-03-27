// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./support/IERC20.sol";
import "./support/SafeERC20.sol";
import "./support/ERC20.sol";
import "./support/utils/ReentrancyGuard.sol";

interface IUniswapV2Router01 {
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IUniswapV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract FairLaunchToken is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public price;
    uint256 public amountPerUnits;

    uint256 public mintLimit;
    uint256 public minted;

    bool public started;
    address public launcher;

    address public uniswapRouter;
    address public uniswapFactory;

    event FairMinted(address indexed to, uint256 amount, uint256 ethAmount);

    event LunchEvent(
        address indexed to,
        uint256 amount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event RefundEvent(address indexed from, uint256 amount, uint256 bnb);

    constructor(
        uint256 _price,
        uint256 _amountPerUnits,
        uint256 totalSupply,
        address _luncher,
        address _uniswapRouter,
        address _uniswapFactory,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        price = _price;
        amountPerUnits = _amountPerUnits;
        started = false;
        _mint(address(this), totalSupply);
        // 50% of total supply for mint
        mintLimit = (totalSupply) / 2;
        // set luncher
        launcher = _luncher;
        // set uniswap router
        uniswapRouter = _uniswapRouter;
        uniswapFactory = _uniswapFactory;
    }

    receive() external payable {
        if (msg.value == 0.0005 ether && !started) {
            if (minted == mintLimit) {
                start();
            } else {
                require(
                    msg.sender == launcher,
                    "FairMint: only launcher can start"
                );
                start();
            }
        } else {
            mint();
        }
    }

    function mint() virtual internal nonReentrant {
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

        _transfer(address(this), msg.sender, units * amountPerUnits);
        minted += units * amountPerUnits;

        emit FairMinted(msg.sender, units * amountPerUnits, realCost);

        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
    }

    function start() internal {
        require(!started, "FairMint: already started");
        address _weth = IUniswapV2Router01(uniswapRouter).WETH();
        address _pair = IUniswapV2Factory(uniswapFactory).getPair(
            address(this),
            _weth
        );

        if (_pair == address(0)) {
            _pair = IUniswapV2Factory(uniswapFactory).createPair(
                address(this),
                _weth
            );
        }
        _pair = IUniswapV2Factory(uniswapFactory).getPair(address(this), _weth);
        // assert pair exists
        assert(_pair != address(0));

        // set started
        started = true;

        // add liquidity
        IUniswapV2Router01 router = IUniswapV2Router01(uniswapRouter);
        uint256 balance = balanceOf(address(this));
        uint256 diff = balance - minted;
        // burn diff
        _burn(address(this), diff);
        _approve(address(this), uniswapRouter, type(uint256).max);
        // add liquidity
        (uint256 tokenAmount, uint256 ethAmount, uint256 liquidity) = router
            .addLiquidityETH{value: address(this).balance}(
            address(this), // token
            minted, // token desired
            minted, // token min
            address(this).balance, // eth min
            address(this), // lp to
            block.timestamp + 1 days // deadline
        );

        emit LunchEvent(address(this), tokenAmount, ethAmount, liquidity);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20) {
        // if not started, only allow refund
        if (!started) {
            if (to == address(this) && from != address(0)) {
                // refund deprecated
            } else {
                // if it is not refund operation, check and revert.
                if (from != address(0) && from != address(this)) {
                    // if it is not INIT action, revert. from address(0) means INIT action. from address(this) means mint action.
                    revert("FairMint: all tokens are locked until launch.");
                }
            }
        } else {
            if (to == address(this) && from != address(0)) {
                revert(
                    "FairMint: You can not send token to contract after launched."
                );
            }
        }
        super._update(from, to, value);
        if (to == address(this) && from != address(0)) {
            _refund(from, value);
        }
    }

    function _refund(address from, uint256 value) internal nonReentrant {
        require(!started, "FairMint: already started");
        require(!_isContract(from), "FairMint: can not refund to contract");
        require(from == tx.origin, "FairMint: can not refund to contract.");
        require(value >= amountPerUnits, "FairMint: value not match");
        require(value % amountPerUnits == 0, "FairMint: value not match");

        uint256 _bnb = (value / amountPerUnits) * price;
        require(_bnb > 0, "FairMint: no refund");

        minted -= value;
        payable(from).transfer(_bnb);
        emit RefundEvent(from, value, _bnb);
    }

    // is contract
    function _isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
// powered by WRB
// https://github.com/WhiteRiverBay/evm-fair-launch
