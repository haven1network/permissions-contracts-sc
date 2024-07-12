// =============================== Transfer Tokens ============================================

const fs = require('fs')
const { ethers } = require("ethers")

async function main() {
  const provider = new ethers.JsonRpcProvider("http://localhost:8545")
  const privateKey = fs.readFileSync('/etc/goquorum/keystore/accountPrivateKey', 'utf8')
  const personal = new ethers.Wallet(privateKey, provider)
  const transactionRequest = { to: "<ADDRESS>", value: ethers.parseUnits("1000000000") }
  
  personal.sendTransaction(transactionRequest).then(console.log)
}

main()
 