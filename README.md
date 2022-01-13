# Dixel
A single NFT canvas where users overwrite the previous edition with price-compounded pixels.

1. There is an universal art canvas with 16x16 pixels that anyone can overwrite
2. Whenever a user overwrites a pixel, the price of the pixel increases by 5% (Initial pixel price: 1 DIXEL)
3. A new NFT edition with the current canvas state will be minted to the updater (image data is encoded as SVG, 100% on-chain)
4. Total cost that user paid to overwrite pixels goes to:
    - 10% -> all contributors proportional to their contribution count (total pixel count a user has updated so far)
    - 90% -> reserve for refund when the NFT gets burned
5. If a user burn a NFT they own, reserve amount (DIXEL tokens) gets refunded to the user (90% of total minting cost)

## Run Tests
```bash
npx hardhat test
```

## Contracts

### BSC Testnet
- Test DIXEL token: 0x596b3f42C39aACbB405810D2011BB35b9142c330
- DixelAirdrop: 0x7B0f17dC4A3Bb4AE1880fc195139B5d705e31224
- DixelArt NFT: 0xebb0Ce00EBFAd67180a256aa9592E1a36A61a726
- Dixel contract: 0x0737Ee66D587baB42b42D608C4Fe712B13bbC9f2

## Deploy
```bash
npx hardhat compile

HARDHAT_NETWORK=bscmain node scripts/deploy.js

# Verify source code on Etherscan
npx hardhat verify --network bscmain {contract address} "parameter 1" "parameter 2"
```

## Gas Consumption
```
·----------------------------------------------------|---------------------------|--------------|-----------------------------·
|                Solc version: 0.8.10                ·  Optimizer enabled: true  ·  Runs: 1500  ·  Block limit: 60000000 gas  │
·····················································|···························|··············|······························
|  Methods                                           ·                1 gwei/gas                ·       3348.19 usd/eth       │
····························|························|·············|·············|··············|···············|··············
|  Contract                 ·  Method                ·  Min        ·  Max        ·  Avg         ·  # calls      ·  usd (avg)  │
····························|························|·············|·············|··············|···············|··············
|  DixelAirdrop             ·  addTokens             ·      69103  ·      90972  ·       80038  ·           46  ·       0.27  │
····························|························|·············|·············|··············|···············|··············
|  DixelAirdrop             ·  claim                 ·          -  ·          -  ·       77230  ·            9  ·       0.26  │
····························|························|·············|·············|··············|···············|··············
|  DixelAirdrop             ·  closeAirdrop          ·          -  ·          -  ·       59767  ·            3  ·       0.20  │
····························|························|·············|·············|··············|···············|··············
|  DixelAirdrop             ·  startAirdrop          ·          -  ·          -  ·       28419  ·            9  ·       0.10  │
····························|························|·············|·············|··············|···············|··············
|  DixelAirdrop             ·  whitelist             ·          -  ·          -  ·      199568  ·           23  ·       0.67  │
····························|························|·············|·············|··············|···············|··············
|  DixelArt                 ·  burn                  ·          -  ·          -  ·       67688  ·            6  ·       0.23  │
····························|························|·············|·············|··············|···············|··············
|  DixelArt                 ·  transferOwnership     ·      28608  ·      28620  ·       28618  ·           64  ·       0.10  │
····························|························|·············|·············|··············|···············|··············
|  DixelMock                ·  claimReward           ·      55825  ·      72925  ·       67225  ·            6  ·       0.23  │
····························|························|·············|·············|··············|···············|··············
|  DixelMock                ·  updatePixels          ·    1231894  ·    1257360  ·     1251418  ·          104  ·       4.19  │
····························|························|·············|·············|··············|···············|··············
|  DixelMock                ·  updatePixelsNoChecks  ·          -  ·          -  ·     3008100  ·            1  ·      10.07  │
····························|························|·············|·············|··············|···············|··············
|  DixelMock                ·  updatePixelsOriginal  ·          -  ·          -  ·     3258315  ·            1  ·      10.91  │
····························|························|·············|·············|··············|···············|··············
|  ERC20PresetMinterPauser  ·  approve               ·      46596  ·      46620  ·       46618  ·          129  ·       0.16  │
····························|························|·············|·············|··············|···············|··············
|  ERC20PresetMinterPauser  ·  mint                  ·      55830  ·      72954  ·       63514  ·          194  ·       0.21  │
····························|························|·············|·············|··············|···············|··············
|  Deployments                                       ·                                          ·  % of limit   ·             │
·····················································|·············|·············|··············|···············|··············
|  ColorUtilsMock                                    ·          -  ·          -  ·      298677  ·        0.5 %  ·       1.00  │
·····················································|·············|·············|··············|···············|··············
|  DixelAirdrop                                      ·    1186871  ·    1186883  ·     1186881  ·          2 %  ·       3.97  │
·····················································|·············|·············|··············|···············|··············
|  DixelArt                                          ·    2813219  ·    2813243  ·     2813242  ·        4.7 %  ·       9.42  │
·····················································|·············|·············|··············|···············|··············
|  DixelMock                                         ·    8175826  ·    8175850  ·     8175848  ·       13.6 %  ·      27.37  │
·····················································|·············|·············|··············|···············|··············
|  ERC20PresetMinterPauser                           ·          -  ·          -  ·     1951544  ·        3.3 %  ·       6.53  │
·----------------------------------------------------|-------------|-------------|--------------|---------------|-------------·
```
