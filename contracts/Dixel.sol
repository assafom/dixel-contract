// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./lib/ColorUtils.sol";
import "./DixelSVGGenerator.sol";
import "./DixelArt.sol";

/**
 * @title Dixel
 *
 * Crowd-sourced pixel art community
 */
contract Dixel is Ownable, ReentrancyGuard, DixelSVGGenerator {
    IERC20 public baseToken;
    DixelArt public dixelArt;

    uint200 private constant GENESIS_PRICE = 1e18; // Initial price: 1 DIXEL
    uint256 private constant PRICE_INCREASE_RATE = 500; // 5% price increase on over-writing
    uint256 private constant REWARD_RATE = 1000; // 10% goes to contributors & 90% goes to NFT contract for refund on burn
    uint256 private constant MAX_RATE = 10000;

    struct Pixel {
        uint24 color; // 24bit integer (000000 - ffffff = 0 - 16777215)
        uint32 owner; // GAS_SAVING: player.id, max 42B users
        uint200 price; // GAS_SAVING
    }

    struct PixelParams {
        uint8 x;
        uint8 y;
        uint24 color;
    }

    struct Player {
        uint32 id;
        uint32 contribution;
        uint192 rewardClaimed;
        uint256 rewardDebt;
    }

    uint256 public totalContribution;
    uint256 internal accRewardPerContribution;

    // Fancy math here:
    //   - player.rewardDebt: Reward amount that should be deducted (the amount accumulated before I joined)
    //   - accRewardPerContribution: Accumulated reward per share (contribution)
    //     (use `accRewardPerContribution * 1e18` because the value is normally less than 1 with many decimals)

    // Example: accRewardPerContribution =
    //   1. reward: 100 (+100) & total contribution: 100 -> 0 + 100 / 100 = 1.0
    //   2. reward: 150 (+50) & total contribution: 200 (+100) -> 1 + 50 / 200 = 1.25
    //   3. reward: 250 (+100) & total contribution: 230 (+30) -> 1.25 + 100 / 230 = 1.68478
    //
    //   => claimableReward = (player.contribution * accRewardPerContribution) - player.rewardDebt
    //
    // Update `accRewardPerContribution` whenever a reward added (new NFT is minted)
    //   => accRewardPerContribution += reward generated / (new)totalContribution
    //
    // Update player's `rewardDebt` whenever the player claim reward or mint a new token (contribution changed)
    //   => player.rewardDebt = accRewardPerContribution * totalContribution

    Pixel[CANVAS_SIZE][CANVAS_SIZE] public pixels;

    // GAS_SAVING: Store player's wallet addresses
    address[] public playerWallets;
    mapping(address => Player) public players;

    event UpdatePixels(
        address player,
        uint16 pixelCount,
        uint96 totalPrice,
        uint96 rewardGenerated
    );
    event ClaimReward(address player, uint256 rewardAmount);

    // solhint-disable-next-line func-visibility
    constructor(address baseTokenAddress, address dixelArtAddress) {
        baseToken = IERC20(baseTokenAddress);
        dixelArt = DixelArt(dixelArtAddress);

        // players[0].id = baseTokenAddress (= token burning)
        playerWallets.push(baseTokenAddress);
        players[baseTokenAddress].id = 0;

        unchecked {
            for (uint256 x = 0; x < CANVAS_SIZE; x++) {
                for (uint256 y = 0; y < CANVAS_SIZE; y++) {
                    // omit initial owner because default value 0 is correct
                    pixels[x][y].price = GENESIS_PRICE;
                }
            }
        }
    }

    function _getOrAddPlayer(address wallet) private returns (Player storage) {
        require(playerWallets.length < 0xffffffff, "MAX_USER_REACHED");

        if (players[wallet].id == 0 && wallet != playerWallets[0]) {
            playerWallets.push(wallet);
            players[wallet].id = uint32(playerWallets.length - 1);
        }

        return players[wallet];
    }

    function updatePixels(PixelParams[] calldata params, uint256 nextTokenId)
        external
        nonReentrant
    {
        require(params.length > 0, "INVALID_PARAMS");
        require(params.length <= CANVAS_SIZE * CANVAS_SIZE, "TOO_MANY_PIXELS");
        require(
            nextTokenId == dixelArt.nextTokenId(),
            "NFT_EDITION_NUMBER_MISMATCHED"
        );

        address msgSender = _msgSender();
        Player storage player = _getOrAddPlayer(msgSender);

        uint256 totalPrice = 0;
        for (uint256 i = 0; i < params.length; i++) {
            Pixel storage pixel = pixels[params[i].x][params[i].y];

            pixel.color = params[i].color;
            pixel.owner = player.id;
            unchecked {
                totalPrice += pixel.price;

                pixel.price = uint200(
                    pixel.price + (pixel.price * PRICE_INCREASE_RATE) / MAX_RATE
                );
            }
        }

        // 10% goes to the contributor reward pools
        uint256 reward = (totalPrice * REWARD_RATE) / MAX_RATE;
        require(
            safeTransferFrom(baseToken, msgSender, address(this), reward),
            "REWARD_TRANSFER_FAILED"
        );

        // 90% goes to the NFT contract for refund on burn
        require(
            safeTransferFrom(
                baseToken,
                msgSender,
                address(dixelArt),
                totalPrice - reward
            ),
            "RESERVE_TRANSFER_FAILED"
        );

        // Keep the pending reward, so it can be deducted from debt at the end (No auto claiming)
        uint256 pendingReward = claimableReward(msgSender);

        // Update acc values before updating contributions so players don't get rewards for their own penalties
        if (totalContribution != 0) {
            // The first reward will be permanently locked on the contract
            _increaseRewardPerContribution(reward);
        }

        unchecked {
            totalContribution += params.length;
            player.contribution += uint32(params.length);
        }

        // Update debt so user can only claim reward from after this event
        unchecked {
            player.rewardDebt =
                _totalPlayerRewardSoFar(player.contribution) -
                pendingReward;

            // Mint NFT to the user
            dixelArt.mint(
                msgSender,
                getPixelColors(),
                uint16(params.length),
                uint96(totalPrice - reward)
            );
        }

        emit UpdatePixels(
            msgSender,
            uint16(params.length),
            uint96(totalPrice),
            uint96(reward)
        );
    }

    function totalPlayerCount() external view returns (uint256) {
        return playerWallets.length - 1; // -1 for wallet[0] = baseToken (burn)
    }

    // MARK: - Reward by contributions

    function _increaseRewardPerContribution(uint256 rewardAdded) private {
        unchecked {
            accRewardPerContribution +=
                (1e18 * rewardAdded) /
                totalContribution;
        }
    }

    function _totalPlayerRewardSoFar(uint32 playerContribution)
        private
        view
        returns (uint256)
    {
        return (accRewardPerContribution * playerContribution) / 1e18;
    }

    function claimableReward(address wallet) public view returns (uint256) {
        return
            _totalPlayerRewardSoFar(players[wallet].contribution) -
            players[wallet].rewardDebt;
    }

    function claimReward() external {
        address msgSender = _msgSender();
        uint256 amount = claimableReward(msgSender);
        require(amount > 0, "NOTHING_TO_CLAIM");

        Player storage player = players[msgSender];
        unchecked {
            player.rewardClaimed += uint192(amount);
        }
        player.rewardDebt = _totalPlayerRewardSoFar(player.contribution); // claimable becomes 0

        require(
            safeTransfer(baseToken, msgSender, amount),
            "REWARD_TRANSFER_FAILED"
        );

        emit ClaimReward(msgSender, amount);
    }

    // MARK: - Draw SVG

    function getPixelColors()
        public
        view
        returns (uint24[CANVAS_SIZE][CANVAS_SIZE] memory pixelColors)
    {
        for (uint256 x = 0; x < CANVAS_SIZE; x++) {
            for (uint256 y = 0; y < CANVAS_SIZE; y++) {
                pixelColors[x][y] = pixels[x][y].color;
            }
        }
    }

    function getPixelOwners() external view returns (address[CANVAS_SIZE][CANVAS_SIZE] memory pixelOwners) {
        for (uint256 x = 0; x < CANVAS_SIZE; x++) {
            for (uint256 y = 0; y < CANVAS_SIZE; y++) {
                pixelOwners[x][y] = playerWallets[pixels[x][y].owner];
            }
        }
    }

    function getPixelPrices() external view returns (uint200[CANVAS_SIZE][CANVAS_SIZE] memory pixelPrices) {
        for (uint256 x = 0; x < CANVAS_SIZE; x++) {
            for (uint256 y = 0; y < CANVAS_SIZE; y++) {
                pixelPrices[x][y] = pixels[x][y].price;
            }
        }
    }

    function generateSVG() external view returns (string memory) {
        return _generateSVG(getPixelColors());
    }

    function generateBase64SVG() external view returns (string memory) {
        return _generateBase64SVG(getPixelColors());
    }

    /// @notice Modified from Gnosis
    /// (https://github.com/gnosis/gp-v2-contracts/blob/main/src/contracts/libraries/GPv2SafeERC20.sol)
    function safeTransferFrom(
        IERC20 tokenAddr,
        address from,
        address to,
        uint256 amount
    ) internal returns (bool success) {
        assembly {
            let freePointer := mload(0x40)
            mstore(
                freePointer,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(
                add(freePointer, 4),
                and(from, 0xffffffffffffffffffffffffffffffffffffffff)
            )
            mstore(
                add(freePointer, 36),
                and(to, 0xffffffffffffffffffffffffffffffffffffffff)
            )
            mstore(add(freePointer, 68), amount)

            let callStatus := call(gas(), tokenAddr, 0, freePointer, 100, 0, 0)

            let returnDataSize := returndatasize()
            if iszero(callStatus) {
                // Copy the revert message into memory.
                returndatacopy(0, 0, returnDataSize)

                // Revert with the same message.
                revert(0, returnDataSize)
            }
            switch returnDataSize
            case 32 {
                // Copy the return data into memory.
                returndatacopy(0, 0, returnDataSize)

                // Set success to whether it returned true.
                success := iszero(iszero(mload(0)))
            }
            case 0 {
                // There was no return data.
                success := 1
            }
            default {
                // It returned some malformed input.
                success := 0
            }
        }
    }

    function safeTransfer(
        IERC20 tokenAddr,
        address to,
        uint256 amount
    ) internal returns (bool success) {
        bool callStatus;

        assembly {
            let freePointer := mload(0x40)
            mstore(
                freePointer,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(
                add(freePointer, 4),
                and(to, 0xffffffffffffffffffffffffffffffffffffffff)
            )
            mstore(add(freePointer, 36), amount)

            callStatus := call(gas(), tokenAddr, 0, freePointer, 68, 0, 0)

            let returnDataSize := returndatasize()
            if iszero(callStatus) {
                // Copy the revert message into memory.
                returndatacopy(0, 0, returnDataSize)

                // Revert with the same message.
                revert(0, returnDataSize)
            }
            switch returnDataSize
            case 32 {
                // Copy the return data into memory.
                returndatacopy(0, 0, returnDataSize)

                // Set success to whether it returned true.
                success := iszero(iszero(mload(0)))
            }
            case 0 {
                // There was no return data.
                success := 1
            }
            default {
                // It returned some malformed input.
                success := 0
            }
        }
    }
}
