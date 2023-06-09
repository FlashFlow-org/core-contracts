// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../../dependencies/openzeppelin/contracts/IERC20.sol';

import { IVenusConnector } from '../../interfaces/connectors/IVenusConnector.sol';
import { CErc20Interface } from '../../interfaces/external/compound-v2/CTokenInterfaces.sol';
import { ComptrollerInterface } from '../../interfaces/external/compound-v2/ComptrollerInterface.sol';

import { UniversalERC20 } from '../../lib/UniversalERC20.sol';

contract VenusConnector is IVenusConnector {
    using UniversalERC20 for IERC20;

    /* ============ Constants ============ */

    /**
     * @dev Venus COMPTROLLER
     */
    ComptrollerInterface internal constant COMPTROLLER =
        ComptrollerInterface(0xfD36E2c2a6789Db23113685031d7F16329158384);

    /**
     * @dev Connector name
     */
    string public constant override NAME = 'Venus';

    /* ============ External Functions ============ */

    /**
     * @dev Deposit ETH/ERC20_Token using the Mapping.
     * @notice Deposit a token to Venus for lending / collaterization.
     * @param _token The address of the token to deposit. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to deposit. (For max: `type(uint).max`)
     */
    function deposit(address _token, uint256 _amount) external payable override {
        CErc20Interface cToken = _getCToken(_token);

        enterMarket(address(cToken));

        IERC20 tokenC = IERC20(_token);
        _amount = _amount == type(uint).max ? tokenC.balanceOf(address(this)) : _amount;
        tokenC.universalApprove(address(cToken), _amount);

        CErc20Interface(cToken).mint(_amount);
    }

    /**
     * @dev Withdraw ETH/ERC20_Token.
     * @notice Withdraw deposited token from Venus
     * @param _token The address of the token to withdraw. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to withdraw. (For max: `type(uint).max`)
     */
    function withdraw(address _token, uint256 _amount) external payable override {
        CErc20Interface cToken = _getCToken(_token);

        if (_amount == type(uint).max) {
            cToken.redeem(cToken.balanceOf(address(this)));
        } else {
            cToken.redeemUnderlying(_amount);
        }
    }

    /**
     * @dev Borrow ETH/ERC20_Token.
     * @notice Borrow a token using Venus
     * @param _token The address of the token to borrow. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to borrow.
     */
    function borrow(address _token, uint256 _amount) external payable override {
        CErc20Interface cToken = _getCToken(_token);

        enterMarket(address(cToken));
        CErc20Interface(cToken).borrow(_amount);
    }

    /**
     * @dev Payback borrowed ETH/ERC20_Token.
     * @notice Payback debt owed.
     * @param _token The address of the token to payback. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to payback. (For max: `type(uint).max`)
     */
    function payback(address _token, uint256 _amount) external payable override {
        CErc20Interface cToken = _getCToken(_token);

        _amount = _amount == type(uint).max ? cToken.borrowBalanceCurrent(address(this)) : _amount;

        IERC20 tokenC = IERC20(_token);
        require(tokenC.balanceOf(address(this)) >= _amount, 'not enough token');

        tokenC.universalApprove(address(cToken), _amount);
        cToken.repayBorrow(_amount);
    }

    /* ============ Public Functions ============ */

    /**
     * @dev Get total debt balance & fee for an asset
     * @param _token Token address of the debt.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _recipient Address whose balance we get.
     */
    function borrowBalanceOf(address _token, address _recipient) public override returns (uint256) {
        CErc20Interface cToken = _getCToken(_token);
        return cToken.borrowBalanceCurrent(_recipient);
    }

    /**
     * @dev Get total collateral balance for an asset
     * @param _token Token address of the collateral.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _recipient Address whose balance we get.
     */
    function collateralBalanceOf(address _token, address _recipient) public override returns (uint256) {
        CErc20Interface cToken = _getCToken(_token);
        return cToken.balanceOfUnderlying(_recipient);
    }

    /**
     * @dev Mapping base token to cToken
     * @param _token Base token address.
     */
    function _getCToken(address _token) public pure override returns (CErc20Interface) {
        if (IERC20(_token).isETH()) {
            return CErc20Interface(0xA07c5b74C9B40447a954e1466938b865b6BBea36);
        }
        if (_token == 0x47BEAd2563dCBf3bF2c9407fEa4dC236fAbA485A) {
            return CErc20Interface(0x2fF3d0F6990a40261c66E1ff2017aCBc282EB6d0);
        }
        if (_token == 0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63) {
            return CErc20Interface(0x151B1e2635A717bcDc836ECd6FbB62B674FE3E1D);
        }
        if (_token == 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d) {
            return CErc20Interface(0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8);
        }
        if (_token == 0x55d398326f99059fF775485246999027B3197955) {
            return CErc20Interface(0xfD5840Cd36d94D7229439859C0112a4185BC0255);
        }
        if (_token == 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56) {
            return CErc20Interface(0x95c78222B3D6e262426483D42CfA53685A67Ab9D);
        }
        if (_token == 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c) {
            return CErc20Interface(0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B);
        }
        if (_token == 0x2170Ed0880ac9A755fd29B2688956BD959F933F8) {
            return CErc20Interface(0xf508fCD89b8bd15579dc79A6827cB4686A3592c8);
        }
        if (_token == 0x4338665CBB7B2485A8855A139b75D5e34AB0DB94) {
            return CErc20Interface(0x57A5297F2cB2c0AaC9D554660acd6D385Ab50c6B);
        }
        if (_token == 0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE) {
            return CErc20Interface(0xB248a295732e0225acd3337607cc01068e3b9c10);
        }
        if (_token == 0x8fF795a6F4D97E7887C79beA79aba5cc76444aDf) {
            return CErc20Interface(0x5F0388EBc2B94FA8E123F404b79cCF5f40b29176);
        }
        if (_token == 0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402) {
            return CErc20Interface(0x1610bc33319e9398de5f57B33a5b184c806aD217);
        }
        if (_token == 0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD) {
            return CErc20Interface(0x650b940a1033B8A1b1873f78730FcFC73ec11f1f);
        }
        if (_token == 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3) {
            return CErc20Interface(0x334b3eCB4DCa3593BCCC3c7EBD1A1C1d1780FBF1);
        }
        if (_token == 0x0D8Ce2A99Bb6e3B7Db580eD848240e4a0F9aE153) {
            return CErc20Interface(0xf91d58b5aE142DAcC749f58A49FCBac340Cb0343);
        }
        if (_token == 0x250632378E573c6Be1AC2f97Fcdf00515d0Aa91B) {
            return CErc20Interface(0x972207A639CC1B374B893cc33Fa251b55CEB7c07);
        }
        if (_token == 0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47) {
            return CErc20Interface(0x9A0AF7FDb2065Ce470D72664DE73cAE409dA28Ec);
        }
        if (_token == 0xbA2aE424d960c26247Dd6c32edC70B295c744C43) {
            return CErc20Interface(0xec3422Ef92B2fb59e84c8B02Ba73F1fE84Ed8D71);
        }
        if (_token == 0xCC42724C6683B7E57334c4E856f4c9965ED682bD) {
            return CErc20Interface(0x5c9476FcD6a4F9a3654139721c949c2233bBbBc8);
        }
        if (_token == 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82) {
            return CErc20Interface(0x86aC3974e2BD0d60825230fa6F355fF11409df5c);
        }
        if (_token == 0xfb6115445Bff7b52FeB98650C87f44907E58f802) {
            return CErc20Interface(0x26DA28954763B92139ED49283625ceCAf52C6f94);
        }
        if (_token == 0x14016E85a25aeb13065688cAFB43044C2ef86784) {
            return CErc20Interface(0x08CEB3F4a7ed3500cA0982bcd0FC7816688084c3);
        }
        if (_token == 0x85EAC5Ac2F758618dFa09bDbe0cf174e7d574D5B) {
            return CErc20Interface(0x61eDcFe8Dd6bA3c891CB9bEc2dc7657B3B422E93);
        }
        if (_token == 0x3d4350cD54aeF9f9b2C29435e0fa809957B3F30a) {
            return CErc20Interface(0x78366446547D062f45b4C0f320cDaa6d710D87bb);
        }
        if (_token == 0x156ab3346823B651294766e23e6Cf87254d68962) {
            return CErc20Interface(0xb91A659E88B51474767CD97EF3196A3e7cEDD2c8);
        }
        if (_token == 0xCE7de646e7208a4Ef112cb6ed5038FA6cC6b12e3) {
            return CErc20Interface(0xC5D3466aA484B040eE977073fcF337f2c00071c1);
        }

        revert('Unsupported token');
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Enter Venus market
     */
    function enterMarket(address cToken) internal {
        address[] memory markets = COMPTROLLER.getAssetsIn(address(this));
        bool isEntered = false;
        for (uint i = 0; i < markets.length; i++) {
            if (markets[i] == cToken) {
                isEntered = true;
            }
        }
        if (!isEntered) {
            address[] memory toEnter = new address[](1);
            toEnter[0] = cToken;
            COMPTROLLER.enterMarkets(toEnter);
        }
    }
}
