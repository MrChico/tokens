pragma solidity ^0.4.24;

import "ds-test/test.sol";

import "./Tokens.sol";

contract TokensTest is DSTest {
    Tokens tokens;

    function setUp() public {
        tokens = new Tokens();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
