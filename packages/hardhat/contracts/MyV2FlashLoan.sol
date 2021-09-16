pragma solidity >=0.6.0 <0.7.0;

import "hardhat/console.sol";

import { FlashLoanReceiverBase } from "./FlashLoanReceiverBase.sol";
import { ILendingPool, ILendingPoolAddressesProvider, IERC20 } from "./Interfaces.sol";
import { SafeMath } from "./Libraries.sol";
import { Constants } from "./Constants.sol";
import { IUniswapV2Router02 } from "./IUniswapV2Router02.sol";

contract MyV2FlashLoan is FlashLoanReceiverBase {
  uint256 private loanSize = 500 ether;

  using SafeMath for uint256;

  struct Addresses {
    address DAI_ADDRESS;
    address WETH_ADDRESS;
    address UNISWAP_ROUTER_ADDRESS;
    address SUSHISWAP_ROUTER_ADDRESS;
  }
    
  Addresses constants = Addresses({
    DAI_ADDRESS : 0x6B175474E89094C44Da98b954EedeAC495271d0F,
    WETH_ADDRESS : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
    UNISWAP_ROUTER_ADDRESS : 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
    SUSHISWAP_ROUTER_ADDRESS : 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F
  });
   
  IUniswapV2Router02 public uniswapRouter;
  IUniswapV2Router02 public sushiswapRouter;

  IERC20 public DAI_ERC20;
  IERC20 public WETH_ERC20;

  constructor(ILendingPoolAddressesProvider _addressProvider) FlashLoanReceiverBase(_addressProvider) public {
    sushiswapRouter = IUniswapV2Router02(constants.SUSHISWAP_ROUTER_ADDRESS);
    uniswapRouter = IUniswapV2Router02(constants.UNISWAP_ROUTER_ADDRESS);

    DAI_ERC20 = IERC20(constants.DAI_ADDRESS);
    WETH_ERC20 = IERC20(constants.WETH_ADDRESS);
    
  }

  /**
    This is helper function to let us know how much DAI and WETH we have at some moment
  */
  function printBalances() private {
    console.log("DAI: ", DAI_ERC20.balanceOf(address(this)));
    console.log("WETH: ", WETH_ERC20.balanceOf(address(this)));
  }

  /**
    This function is called after your contract has received the flash loaned amount
  */
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  )
    external
    override
    returns (bool)
  {
    printBalances();

    uint256 startingDAI = DAI_ERC20.balanceOf(address(this));
    console.log("DAI before trade: ", startingDAI);

    address[] memory path = new address[](2);
    path[0] = constants.DAI_ADDRESS;
    path[1] = constants.WETH_ADDRESS;

    DAI_ERC20.approve(constants.UNISWAP_ROUTER_ADDRESS, loanSize);
    uniswapRouter.swapExactTokensForTokens(loanSize, 0, path, address(this), block.timestamp + 5);

    printBalances();

    address[] memory revPath = new address[](2);
    revPath[0] = constants.WETH_ADDRESS;
    revPath[1] = constants.DAI_ADDRESS;

    uint256 WETHBalance = WETH_ERC20.balanceOf(address(this));

    WETH_ERC20.approve(constants.SUSHISWAP_ROUTER_ADDRESS, WETHBalance);
    sushiswapRouter.swapExactTokensForTokens(WETHBalance, 0, revPath, address(this), block.timestamp + 5);

    printBalances();

    for (uint i = 0; i < assets.length; i++) {
      uint256 amountOwing = amounts[i].add(premiums[i]);
      IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
    }

    uint256 finalDAI = DAI_ERC20.balanceOf(address(this));
    console.log("DAI after trade: ", finalDAI);

    require(finalDAI > startingDAI, "Trade not profitable");

    return true;
  }

  function myFlashLoanCall() public {
    address receiverAddress = address(this);

    address[] memory assets = new address[](1);
    assets[0] = address(constants.DAI_ADDRESS);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = loanSize;

    uint256[] memory modes = new uint256[](1);
    modes[0] = 0;

    address onBehalfOf = address(this);
    bytes memory params = "";
    uint16 referralCode = 0;

    LENDING_POOL.flashLoan(
      receiverAddress,
      assets,
      amounts,
      modes,
      onBehalfOf,
      params,
      referralCode
    );
  }
}
