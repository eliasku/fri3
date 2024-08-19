import wasm from "../zig-out/bin/main.wasm?url";
import { importMap, run } from "./lib";

WebAssembly.instantiateStreaming(fetch(wasm), importMap).then((source) =>
  run(source.instance),
);
