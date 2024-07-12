module.exports = {
  networks: {
    qn1: {
      network_id: "8110",
      port: 8545,
      host: "127.0.0.1",
      gasPrice: 0,
      websockets: false
    },
  },
  
  mocha: {
    timeout: 100000
  },

  compilers: {
    solc: {
      version: "0.5.3"
    }
  },
};
