// SPDX-License-Identifier: MIT
// WRB
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

contract CommandableFairLaunchToken is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // refund command
    // before start, you can always refund
    // send 0.0002 ether to the contract address to refund all ethers
    uint256 public constant REFUND_COMMAND = 0.0002 ether;

    // start trading command
    // if the untilBlockNumber reached, you can start trading with this command
    // send 0.0005 ether to the contract address to start trading
    uint256 public constant START_COMMAND = 0.0005 ether;

    // mint command
    // if the untilBlockNumber reached, you can mint token with this command
    // send 0.0001 ether to the contract address to get tokens
    uint256 public constant MINT_COMMAND = 0.0001 ether;

    // is trading started
    bool public started;

    address public uniswapRouter;
    address public uniswapFactory;

    // fund balance
    mapping(address => uint256) public fundBalanceOf;

    // is address minted
    mapping(address => bool) public minted;

    // total dispatch amount
    uint256 public totalDispatch;

    // until block number
    uint256 public untilBlockNumber;

    // total ethers funded
    uint256 public totalEthers;

    // how many tokens are reserved by the issuer
    uint256 public reserve;

    event FundEvent(
        address indexed from, 
        uint256 amount
    );

    event FairMinted(
        address indexed to, 
        uint256 amount, 
        uint256 ethAmount
    );

    event LunchEvent(
        address indexed to,
        uint256 amount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event RefundEvent(
        address indexed from, 
        uint256 amount
    );

    /**
     *    @param totalSupply total supply of the token
     *    @param _uniswapRouter uniswap router address
     *    @param _uniswapFactory uniswap factory address
     *    @param _name token name
     *    @param _symbol token symbol
     *    @param _afterBlock after how many blocks you can start trading
     *    @param _reservedTokens reserved tokens, if you want to reserve some tokens, you can set it
     *    @param _issuer issuer address
     */
    constructor(
        uint256 totalSupply,
        address _uniswapRouter,
        address _uniswapFactory,
        string memory _name,
        string memory _symbol,
        uint256 _afterBlock,
        uint256 _reservedTokens, 
        address _issuer
    ) ERC20(_name, _symbol) {
        started = false;

        totalDispatch = totalSupply - _reservedTokens;
        _mint(address(this), totalDispatch);

        // set uniswap router
        uniswapRouter = _uniswapRouter;
        uniswapFactory = _uniswapFactory;

        untilBlockNumber = _afterBlock + block.number;

        // if there are reserved tokens, mint it to the issuer immediately
        if (_reservedTokens > 0) {
            _mint(_issuer, _reservedTokens);
        }
    }

    receive() external payable {
        require(tx.origin == msg.sender, "FairMint: can not mint to contract.");
        if (started) {
            if (msg.value == MINT_COMMAND) {
                // mint token
                _mintToken();
            } else {
                revert("FairMint: invalid command");
            }
        } else {
            if (block.number >= untilBlockNumber) {
                if (msg.value == REFUND_COMMAND) {
                    // before start, you can always refund
                    _refund();
                } else if (msg.value == START_COMMAND) {
                    // start trading, add liquidity to uniswap
                    _start();
                } else {
                    revert("FairMint: invalid command");
                }
            } else {
                if (msg.value == REFUND_COMMAND) {
                    // before start, you can always refund
                    _refund();
                } else {
                    // before start, any other value will be considered as fund
                    _fund();
                }
            }
        }
    }

    // estimate how many tokens you might get
    function mightGet(address account) public view returns (uint256) {
        uint256 _mintAmount = (totalDispatch/ 2 * fundBalanceOf[account]) /
            totalEthers;
        return _mintAmount;
    }

    function _fund() internal nonReentrant {
        // require msg.value > 0.0001 ether
        require(msg.value >= 0.0001 ether, "FairMint: value too low");
        fundBalanceOf[msg.sender] += msg.value;
        totalEthers += msg.value;
        emit FundEvent(msg.sender, msg.value);
    }

    function _refund() internal nonReentrant {
        require(msg.value == REFUND_COMMAND, "FairMint: value not match");
        require(!started, "FairMint: already started");

        address account = msg.sender;
        uint256 amount = fundBalanceOf[account];
        require(amount > 0, "FairMint: no fund");
        fundBalanceOf[account] = 0;
        totalEthers -= amount;

        payable(account).transfer(amount + REFUND_COMMAND);
        emit RefundEvent(account, amount);
    }

    function _mintToken() internal virtual nonReentrant {
        // require(started, "FairMint: not started");
        require(block.number >= untilBlockNumber, "FairMint: not started yet");

        require(msg.value == MINT_COMMAND, "FairMint: value not match");
        require(msg.sender == tx.origin, "FairMint: can not mint to contract.");
        require(!minted[msg.sender], "FairMint: already minted");

        minted[msg.sender] = true;

        uint256 _mintAmount = (totalDispatch / 2 * fundBalanceOf[msg.sender]) /
            totalEthers;

        require(_mintAmount > 0, "FairMint: mint amount is zero");
        assert (_mintAmount <= totalDispatch / 2);
        _transfer(address(this), msg.sender, _mintAmount);

        payable(msg.sender).transfer(MINT_COMMAND);
    }

    function _start() internal nonReentrant {
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
        assert(_pair != address(0));
        // set started
        started = true;

        IUniswapV2Router01 router = IUniswapV2Router01(uniswapRouter);
        _approve(address(this), uniswapRouter, type(uint256).max);

        // add liquidity
        (uint256 tokenAmount, uint256 ethAmount, uint256 liquidity) = router
            .addLiquidityETH{value: address(this).balance}(
            address(this), // token
            totalDispatch / 2, // token desired
            totalDispatch / 2, // token min
            address(this).balance, // eth min
            address(this), // lp to
            block.timestamp + 1 days // deadline
        );

        _dropLP(_pair);
        emit LunchEvent(address(this), tokenAmount, ethAmount, liquidity);
    }

    function _dropLP(address lp) internal virtual {
        IERC20 lpToken = IERC20(lp);
        lpToken.safeTransfer(address(0), lpToken.balanceOf(address(this)));
    }
}
// powered by WRB
// https://github.com/WhiteRiverBay/evm-fair-launch

