/// ENVVAR
// - ENABLE_GAS_REPORT
// - COMPILE_MODE

require('dotenv').config();

const path = require('path');
const argv = require('yargs/yargs')()
  .env('')
  .boolean('enableGasReport')
  .boolean('ci')
  .string('compileMode')
  .argv;

require('@nomiclabs/hardhat-truffle5');
require('@nomiclabs/hardhat-solhint');
require('solidity-coverage');

require('hardhat-gas-reporter');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-web3');
require("@nomiclabs/hardhat-etherscan");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.8.10',
    settings: {
      optimizer: {
        enabled: true, // argv.enableGasReport || argv.compileMode === 'production',
        runs: 1500,
      },
    },
  },
  networks: {
    hardhat: {
      blockGasLimit: 60000000,
    },
    bsctest: {
      url: `https://data-seed-prebsc-1-s2.binance.org:8545/`,
      chainId: 97,
      gasPrice: 10000000000, // 10 GWei
      blockGasLimit: 60000000, // 60M
      accounts: [process.env.BSC_TEST_PRIVATE_KEY]
    },
    bscmain: {
      url: `https://bsc-dataseed.binance.org`,
      chainId: 56,
      gasPrice: 6000000000, // 6 GWei
      blockGasLimit: 60000000, // 60M
      accounts: [process.env.BSC_PRIVATE_KEY]
    }
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 1, // HACK For BSC: 5 gewei * 552/4012
    coinmarketcap: process.env.COIN_MARKET_CAP_API
  },
  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY
  },
  mocha: {
    timeout: 60000 // 1 minute for test timeout
  }
};

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});
