/* IMPORT NODE MODULES
================================================== */
import { readFileSync, readdirSync, statSync } from "fs";
import { join } from "path";

/* CONSTANTS
================================================== */
const CONTRACTS_DIR = "contracts";
const EXCLUDED_DIRS = [];

/* MAIN
================================================== */
async function main() {
    /** @type number */
    let lineCount = 0;

    /** @type {Object<string, number>} */
    let files = {};

    const fileNames = getSolidityFiles(CONTRACTS_DIR);
    const l = fileNames.length;

    for (let i = 0; i < l; ++i) {
        const f = fileNames[i];
        const c = count(f);

        files[f] = c;
        lineCount += c;
    }

    Object.keys(files).forEach(k => console.log(`${k}: ${files[k]}`));
    console.log("\n==================================================\n");
    console.log("Total Count: ", lineCount);
}

/* HELPERS
================================================== */
/**
 * Recursively fetch all Solidity files in a directory, excluding files
 * in the specified excluded directories.
 *
 * @function    getSolidityFiles
 * @param       {string}    dir
 * @returns     {string[]}  An array of file paths.
 */
function getSolidityFiles(dir) {
    let fileList = [];

    const files = readdirSync(dir);

    for (let i = 0; i < files.length; ++i) {
        const file = files[i];
        const filePath = join(dir, file);
        const stat = statSync(filePath);

        if (stat.isDirectory()) {
            if (!EXCLUDED_DIRS.includes(file)) {
                fileList = fileList.concat(getSolidityFiles(filePath));
            }
        } else if (file.endsWith(".sol")) {
            fileList.push(filePath);
        }
    }

    return fileList;
}

/**
 * Reads the entire file at `fileName` into memory and counts the lines that
 * are not comments and not blank lines.
 *
 * @function    count
 * @param       {string}    fileName
 * @returns     {number}    The amount of lines in the file that are not blank or comments.
 */
function count(fileName) {
    let lineCount = 0;

    const data = readFileSync(fileName, "utf8");
    const lines = data.split("\n");

    for (let i = 0; i < lines.length; ++i) {
        const trimmed = lines[i].trim();
        if (shouldCount(trimmed)) lineCount++;
    }

    return lineCount;
}

/**
 * Returns whether a given line is valid and should be counted.
 *
 * @function     shouldCount
 * @param        {string}       line
 * @returns      {boolean}      Whether the given line should be counted.
 */
function shouldCount(line) {
    return line !== "" && !line.startsWith("/") && !line.startsWith("*");
}

/* RUN
================================================== */
main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
