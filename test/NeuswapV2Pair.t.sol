// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NeuswapV2Pair.sol";
import "./mocks/ERC20Mintable.sol";

contract NeuswapV2PairTest is Test {
  ERC20Mintable token0;
  ERC20Mintable token1;
  NeuswapV2Pair pair;
  TestUser testUser;

  function setUp() public {
    testUser = new TestUser();

    token0 = new ERC20Mintable("Token A", "TKNA");
    token1 = new ERC20Mintable("Token B", "TKNB");
    pair = new NeuswapV2Pair(address(token0), address(token1));

    token0.mint(10 ether, address(this));
    token1.mint(10 ether, address(this));

    token0.mint(10 ether, address(testUser));
    token1.mint(10 ether, address(testUser));
  }

  function assertReserve(uint112 expectedReserve0, uint112 expectedReserve1) internal {
    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
    assertEq(reserve0, expectedReserve0, "unexpected reserve0");
    assertEq(reserve1, expectedReserve1, "unexpected reserve1");
  }

  function testMintBootstrap() public {
    token0.transfer(address(pair), 1 ether);
    token1.transfer(address(pair), 1 ether);

    pair.mint();

    assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
    assertReserve(1 ether, 1 ether);
    assertEq(pair.totalSupply(), 1 ether);
  }

  function testMintWhenTheresLiquidity() public {
    token0.transfer(address(pair), 1 ether);
    token1.transfer(address(pair), 1 ether);
    pair.mint();

    vm.warp(37);

    token0.transfer(address(pair), 2 ether);
    token1.transfer(address(pair), 2 ether);
    pair.mint();

    assertEq(pair.balanceOf(address(this)), 3 ether - 1000);
    assertEq(pair.totalSupply(), 3 ether);
    assertReserve(3 ether, 3 ether);
  }

  function testMintUnbalanced() public {
    token0.transfer(address(pair), 1 ether);
    token1.transfer(address(pair), 1 ether);
    pair.mint();

    assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
    assertReserve(1 ether, 1 ether);

    token0.transfer(address(pair), 2 ether);
    token1.transfer(address(pair), 1 ether);
    pair.mint();

    assertEq(pair.balanceOf(address(this)), 2 ether - 1000);
    assertEq(pair.totalSupply(), 2 ether);
    assertReserve(3 ether, 2 ether);
  }

  function testMintLiquidityUnderFlow() public {
    // 0x11: if an arithmetic result in underflow or overflow outside of an unchecked { ... } block.
    vm.expectRevert(
      hex"4e487b710000000000000000000000000000000000000000000000000000000000000011"
    );
    pair.mint();
  }

  function testMintZeroLiquidity() public {
    token0.transfer(address(pair), 1000);
    token1.transfer(address(pair), 1000);

    vm.expectRevert(bytes(hex"d226f9d4")); // InsufficientLiquidityMinted()
    pair.mint();
  }

  function testBurn() public {
    token0.transfer(address(pair), 1 ether);
    token1.transfer(address(pair), 1 ether);
    pair.mint();

    pair.burn();
    assertEq(pair.balanceOf(address(this)), 0);
    assertEq(pair.totalSupply(), 1000);
    assertReserve(1000, 1000);
    assertEq(token0.balanceOf(address(this)), 10 ether - 1000);
    assertEq(token1.balanceOf(address(this)), 10 ether - 1000);
  }

  function testBurnableUnbalanced() public {
    token0.transfer(address(pair), 1 ether);
    token1.transfer(address(pair), 1 ether);
    pair.mint();

    assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
    assertReserve(1 ether, 1 ether);

    token0.transfer(address(pair), 2 ether);
    token1.transfer(address(pair), 1 ether);
    pair.mint();

    pair.burn();

    assertEq(pair.balanceOf(address(this)), 0);
    assertReserve(1500, 1000);
    assertEq(pair.totalSupply(), 1000);
    assertEq(token0.balanceOf(address(this)), 10 ether - 1500);
    assertEq(token1.balanceOf(address(this)), 10 ether - 1000);
  }

  function testBurnUnblancedDifferentUser() public {
    testUser.provideLiquidity(
      address(pair), 
      address(token0), 
      address(token1), 
      1 ether, 
      1 ether
    );

    assertEq(pair.balanceOf(address(this)), 0);
    assertEq(pair.balanceOf(address(testUser)), 1 ether - 1000);
    assertEq(pair.totalSupply(), 1 ether);

    token0.transfer(address(pair), 2 ether);
    token1.transfer(address(pair), 1 ether);
    pair.mint();
    pair.burn();

    assertEq(pair.balanceOf(address(this)), 0);
    assertReserve(1.5 ether, 1 ether);
    assertEq(pair.totalSupply(), 1 ether);
    assertEq(token0.balanceOf(address(this)), 10 ether - 0.5 ether);
    assertEq(token1.balanceOf(address(this)), 10 ether);

    testUser.withdrawLiquidity(address(pair));

    assertEq(pair.balanceOf(address(testUser)), 0);
    assertReserve(1500, 1000);
    assertEq(pair.totalSupply(), 1000);
    assertEq(token0.balanceOf(address(testUser)), 10 ether + 0.5 ether - 1500);
    assertEq(token1.balanceOf(address(testUser)), 10 ether - 1000);
  }

  function testBurnZeroTotalSupply() public {
    // 0x12: If you divide or modulo by zero
    vm.expectRevert(hex"4e487b710000000000000000000000000000000000000000000000000000000000000012");
    pair.burn();
  }

  function testBurnZeroLiquidity() public {
    token0.transfer(address(pair), 1 ether);
    token1.transfer(address(pair), 1 ether);
    pair.mint();

    // Burn as a user who hasn't privided liquidity
    // bytes memory prankData = abi.encodeWithSignature("burn()");
    vm.prank(address(0xdeadbeef));
    vm.expectRevert(bytes(hex"749383ad")); // InsufficientLiquidityBurned()
    pair.burn();
  }

  function testReservePacking() public {
    token0.transfer(address(pair), 1 ether);
    token1.transfer(address(pair), 2 ether);
    pair.mint();

    bytes32 val = vm.load(address(pair), bytes32(uint256(8)));
    assertEq(val, hex"000000000000000000001bc16d674ec800000000000000000de0b6b3a7640000");
  }
} 

contract TestUser {
  function provideLiquidity(
    address _pairAddress,
    address _token0Address,
    address _token1Address,
    uint256 _amount0,
    uint256 _amount1
  ) public {
    ERC20(_token0Address).transfer(_pairAddress, _amount0);
    ERC20(_token1Address).transfer(_pairAddress, _amount1);

    NeuswapV2Pair(_pairAddress).mint();
  }

  function withdrawLiquidity(address _pairAddress) public {
    NeuswapV2Pair(_pairAddress).burn();
  }
}