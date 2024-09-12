import wasm from "../zig-out/bin/main.wasm?url";
import { importMap, run } from "./lib";

fetch(wasm)
  .then(v => v.arrayBuffer())
  .then(i => WebAssembly.instantiate(i, importMap))
  .then(s => run(s.instance));