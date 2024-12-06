module.exports = {
    // See:
    // https://github.com/sc-forks/solidity-coverage
    skipFiles: [],
    configureYulOptimizer: true,
    solcOptimizerDetails: {
        yul: true,
        yulDetails: {
            optimizerSteps: "",
        },
    },
};
