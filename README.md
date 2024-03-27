# >>> TRUST NO ONE BUT THE CODE  <<<

- There are no administrators, no special withdrawal rights, no rats, no one can be faster than others, no one can RUG, all funds raised are added to the liquidity pool.

- This contract is a token contract inherited from ERC20
- Added fair launch function to uniswap-v2 liquidity pool
- Players only need to transfer the corresponding ethers to the contract to obtain tokens
- Players can transfer tokens to the contract at any time before launch to obtain refunds
- When the conditions are met, players only need to transfer 0.0005 ether to the contract, and the contract will send the equivalent tokens of all sold tokens and all ethers in the contract to the DEX exchange to add liquidity. The token can be traded immediately.
- Currently only the Uniswap-V2 version of the contract is provided
- Prevent adding liquidity before launch

## NOTE
Note that in the fair-launch-uniswap-v2.sol contract, all liquid LP Tokens will be permanently locked in the contract and cannot be withdrawn.

I am developing a contract that allows the withdrawal of LP returns (a version that allows the withdrawal of fee income generated during the transaction process) to provide incentives for the project side to continue operating.


## USAGE - Parameter Description:
 ```
  _PRICE: Price per share
  _AMOUNTPERUNITS: How many TOKEN each copy contains
  _TOTALSUPPLY: Total supply of tokens
  _LAUNCHER: Who can start the launch if the pre-sale is not completed (anyone can start if it is completed)
  _UNISWAPROUTER: uniswap v2 router address
  _UNISWAPFACTORY: uniswap v2 factory address
  _name: name of token
  _symbol: symbol of token
```



## MIT License

Copyright (c) 2024 White river bay

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


