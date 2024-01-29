// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.10;

import "solmate/tokens/ERC20.sol";
import "./libraries/Math.sol";

interface IERC20 {
  /// @notice Get the balance of an address
  /// @param _owner The address for which to retrieve the balance
  /// @return The balance of the specified address
  function balanceOf(address _owner) external returns (uint256);

  /// @notice Transfer tokens to a specified address
  /// @param _to The recipient address
  /// @param _amount The amount of tokens to transfer
  function transfer(address _to, uint256 _amount) external;
}

error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();

/// @title NeuswapV2Pair
/// @dev A Solidity contract representing a Uniswap V2-like pair for two ERC20 tokens
contract NeuswapV2Pair is ERC20, Math {
  /// @dev Minimum liquidity required for the pair
  uint256 constant MINIMUM_LIQUIDITY = 1000;

  /// @dev Address of the first token in the pair
  address public token0;

  /// @dev Address of the second token in the pair
  address public token1;

  /// @dev Reserve of the first token in the pair
  uint112 private reserve0;

  /// @dev Reserve of the second token in the pair
  uint112 private reserve1;

  /// @dev Event emitted on burning liquidity
  event Burn(address indexed sender, uint256 amount0, uint256 amount1);

  /// @dev Event emitted on minting liquidity
  event Mint(address indexed sender, uint256 amount0, uint256 amount1);

  /// @dev Event emitted on syncing reserves
  event Sync(uint256 reserve0, uint256 reserve1);

  /// @notice Creates a new NeuswapV2Pair instance
  /// @param _token0 Address of the first token
  /// @param _token1 Address of the second token
  constructor(address _token0, address _token1) ERC20("NeuswapV2 Pair", "NEUV2", 18) {
    token0 = _token0;
    token1 = _token1;
  }

  /// @notice Gets the reserves of the pair
  /// @return reserve0 Reserve of the first token, reserve1 Reserve of the second token, 0
  function getReserves() public view returns (uint112, uint112, uint32) {
    return (reserve0, reserve1, 0);
  }

  /// @notice Mints liquidity tokens
  /// @dev The caller must have approved the contract to transfer tokens on their behalf
  function mint() public {
    (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
    uint256 balance0 = IERC20(token0).balanceOf(address(this));
    uint256 balance1 = IERC20(token1).balanceOf(address(this));
    uint256 amount0 = balance0 - _reserve0;
    uint256 amount1 = balance1 - _reserve1;
    uint256 liquidity;

    if (totalSupply == 0) {
      liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
      _mint(address(0), MINIMUM_LIQUIDITY);
    } else {
      liquidity = Math.min(
        (amount0 * totalSupply) / _reserve0,
        (amount1 * totalSupply) / _reserve1
      );
    }

    if (liquidity <= 0) {
      revert InsufficientLiquidityMinted();
    }

    _mint(msg.sender, liquidity);
    _update(balance0, balance1);
    emit Mint(msg.sender, amount0, amount1);
  }

  /// @notice Burns liquidity tokens and transfers underlying tokens to the caller
  /// @dev The caller must have approved the contract to transfer liquidity tokens on their behalf
  function burn() public {
    uint256 balance0 = IERC20(token0).balanceOf(address(this));
    uint256 balance1 = IERC20(token1).balanceOf(address(this));
    uint256 liquidity = balanceOf[msg.sender];

    uint256 amount0 = (liquidity * balance0) / totalSupply;
    uint256 amount1 = (liquidity * balance1) / totalSupply;

    if (amount0 <= 0 || amount1 <= 0) revert InsufficientLiquidityBurned();

    _burn(msg.sender, liquidity);
    _safeTransfer(token0, msg.sender, amount0);
    _safeTransfer(token1, msg.sender, amount1);

    balance0 = IERC20(token0).balanceOf(address(this));
    balance1 = IERC20(token1).balanceOf(address(this));

    _update(balance0, balance1);

    emit Burn(msg.sender, balance0, balance1);
  }

  /// @notice Syncs the reserves of the pair with the current token balances
  function sync() public {
    _update(
      IERC20(token0).balanceOf(address(this)),
      IERC20(token1).balanceOf(address(this))
    );
  }

  		
  /**
   *
   * Private Function
   *  
   */

  /// @dev Updates the reserves of the pair
  function _update(uint256 balance0, uint256 balance1) private {
    reserve0 = uint112(balance0);
    reserve1 = uint112(balance1);

    emit Sync(reserve0, reserve1);
  }

  /// @dev Safely transfers tokens from the contract to a specified address
  function _safeTransfer(
    address token,
    address to,
    uint256 value
  ) private {
    (bool ok, bytes memory data) = token.call(
      abi.encodeWithSignature("transfer(address,uint256)", to, value)
    );

    if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) {
      revert TransferFailed();
    }
  }
}
