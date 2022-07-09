const { exec } = require("child_process");
const prompt = require("prompt-sync")({ sigint: true });

const name = prompt("Enter script name: ");
const version = prompt("Enter script version: ");

const minify = prompt("Minify (y/n): ");
const verbose = prompt("Verbose (y/n): ");
const debug = prompt("Debug (y/n): ");

function getYesNo(name, value) {
  if (value) {
    if (value.toLowerCase() === "y") {
      return name;
    } else {
      return "";
    }
  }
}

const log = console.log;

log("\x1b[33m", "Building...");

exec(
  `remodel run bundler/bundle.lua ${name} ${version} ${getYesNo(
    "minify",
    minify
  )} ${getYesNo("verbose", verbose)} ${getYesNo("debug", debug)}`
);

log("\x1b[32m", `Finished: Written to output/${name}-build.lua`);
log("\x1b[0m");
