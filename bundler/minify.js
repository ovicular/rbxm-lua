const luamin = require("luamin");
const path = require("path");
const fs = require("fs");

const result = luamin.minify(
  fs.readFileSync(path.join(__dirname, "/bundle.tmp"), "utf8")
);

fs.writeFileSync("bundle/bundle.tmp", result);
