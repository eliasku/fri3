// vite.config.ts
import {
  js13kViteConfig,
  defaultViteBuildOptions,
  defaultRollupOptions,
  defaultTerserOptions
} from "file:///Users/eliasku/ek/js13k-2024/node_modules/js13k-vite-plugins/dist/esm/index.mjs";
import { defineConfig } from "file:///Users/eliasku/ek/js13k-2024/node_modules/vite/dist/node/index.js";
import { ViteMinifyPlugin } from "file:///Users/eliasku/ek/js13k-2024/node_modules/vite-plugin-minify/dist/index.js";
import glsl from "file:///Users/eliasku/ek/js13k-2024/node_modules/vite-plugin-glsl/src/index.js";

// vite-zig.ts
import { spawn as spawn2 } from "node:child_process";

// wasmopt.ts
import { dirname, basename, join } from "node:path";
import { spawn, execFileSync } from "node:child_process";
import * as FS from "node:fs/promises";
var run = (cmd, args) => {
  const child = spawn(cmd, args, {
    stdio: "inherit"
  });
  return new Promise((resolve, reject) => {
    child.on("error", reject);
    child.on("close", resolve);
  });
};
var wasmopt = async (options) => {
  const inputWasmSize = (await FS.stat(options.file)).size;
  console.info("Input WASM size:", inputWasmSize);
  const binaryen = process.env.BINARYEN_ROOT;
  const buildDir = dirname(options.file);
  const name = basename(options.file, ".wasm");
  const optFlags = ["-Os", "-Oz", "-O", "-O2", "-O3", "-O4"];
  const passFlags = (opt) => [
    // "-c",
    //"--shrink-level=10000",
    // "--avoid-reinterprets",
    // "--ignore-implicit-traps",
    // "--traps-never-happen",
    // "--fast-math",
    // "--zero-filled-memory",
    // "--closed-world",
    // "--disable-sign-ext",
    // "--dce",
    // "--simplify-globals-optimizing",
    // "--simplify-locals-notee",
    //"--alignment-lowering",
    //"--dealign",
    // "--memory-packing",
    // "--optimize-casts",
    // "--always-inline-max-function-size=0",
    // "--flexible-inline-max-function-size=0"
    //"-Oz",
    "--converge",
    "--low-memory-unused",
    opt,
    "-tnh",
    "--enable-nontrapping-float-to-int",
    // "--enable-simd",
    // "--enable-sign-ext",
    "--enable-bulk-memory",
    // "--enable-mutable-globals",
    // "--enable-multivalue",
    // "--enable-extended-const",
    "--fast-math",
    //"--generate-global-effects", "-Oz",
    // passes:
    "-O4",
    "--gufa",
    "--flatten",
    "--rereloop",
    // "--i64-to-i32-lowering",
    opt,
    "--intrinsic-lowering",
    // "--memory-packing",
    "--precompute-propagate",
    "--avoid-reinterprets",
    "--untee",
    "--vacuum",
    "--cfp"
    // "--optimize-casts",
    // "--optimize-instructions",
    // "--dae",
    // "--dae-optimizing",
  ];
  const files = await Promise.all(
    optFlags.map(async (relinkFlag) => {
      const filepath = `${buildDir}/${name}${relinkFlag}.wasm`;
      await run(`${binaryen}/bin/wasm-opt`, [
        ...passFlags(relinkFlag),
        relinkFlag,
        `${buildDir}/${name}.wasm`,
        `-o`,
        filepath
      ]);
      return await FS.stat(filepath);
    })
  );
  let minSize = 2147483647;
  let minFile;
  let bestFlag;
  const advzip = "advzip";
  const tempFiles = [];
  for (let i = 0; i < optFlags.length; ++i) {
    const optFlag = optFlags[i];
    const optFile = `${buildDir}/${name}${optFlag}.wasm`;
    const wasmSize = files[i].size;
    const zipfilename = `${buildDir}/${name}${optFlag}.wasm.zip`;
    const result = execFileSync(advzip, [
      "--shrink-insane",
      "-a",
      zipfilename,
      optFile
    ]);
    tempFiles.push(optFile, zipfilename);
    const zippedSize = (await FS.stat(zipfilename)).size;
    console.info(`${optFlag} : ${wasmSize} bytes >> ${zippedSize}`);
    if (zippedSize < minSize) {
      bestFlag = optFlag;
      minSize = zippedSize;
      minFile = optFile;
    }
  }
  if (minFile) {
    await FS.copyFile(minFile, `${buildDir}/${name}.wasm`);
    console.info("WASM SIZE: " + minSize + " bytes (" + bestFlag + ")");
  }
  await Promise.all(tempFiles.map((filepath) => FS.unlink(filepath)));
  if (options.dis) {
    await run(join(binaryen, "bin/wasm-dis"), [
      "-o",
      options.dis,
      `${buildDir}/${name}.wasm`
    ]);
  }
};

// vite-zig.ts
var run2 = (cmd, args) => {
  const child = spawn2(cmd, args, {
    stdio: "inherit"
  });
  return new Promise((resolve, reject) => {
    child.on("error", reject);
    child.on("close", resolve);
  });
};
var zig = (options = {}) => {
  let logger;
  const build = options.build ?? "./build.zig";
  const watch = options.watch ?? /^.+\.zig$/;
  const checkFile = (filepath) => watch.test(filepath);
  const runBuild = async (command) => {
    const zig2 = "zig";
    let ts = performance.now();
    let errorsCount = 0;
    const args = ["build", "--summary", "all", "--build-file", build];
    if (command === "build") {
      args.push("-Drelease=true");
    }
    const result = await run2(zig2, args);
    const compileError = result !== 0;
    if (compileError) {
      ++errorsCount;
    }
    logger.info(`[vite-zig] build is done ${performance.now() - ts | 0} ms`);
    if (compileError) {
      logger.error("[vite-zig] failed, check compile errors");
    } else if (command == "build") {
      try {
        let ts2 = performance.now();
        await wasmopt({
          file: "zig-out/bin/main.wasm",
          dis: "zig-out/bin/main.wast"
        });
        logger.info(
          `[wasmopt] optimized in ${performance.now() - ts2 | 0} ms`
        );
      } catch (err) {
        logger.warn(`[wasmopt] error:`);
        logger.error(err);
      }
    }
  };
  let changed = true;
  let buildInProgress = false;
  return {
    name: "zig",
    enforce: "pre",
    async configResolved(config) {
      logger = config.logger;
      if (config.command === "serve") {
        setInterval(async () => {
          if (changed && !buildInProgress) {
            changed = false;
            buildInProgress = true;
            await runBuild(config.command);
            buildInProgress = false;
          }
        }, 200);
      } else {
        await runBuild(config.command);
      }
    },
    async configureServer(server) {
      server.watcher.on("add", (filepath) => {
        if (checkFile(filepath)) {
          logger.info("[vite-zig] file is added: " + filepath);
          changed = true;
        }
      }).on("change", (filepath) => {
        if (checkFile(filepath)) {
          logger.info("[vite-zig] file is changed: " + filepath);
          changed = true;
        }
      }).on("unlink", (filepath) => {
        if (checkFile(filepath)) {
          logger.info("[vite-zig] file is removed: " + filepath);
          changed = true;
        }
      }).on("error", (error) => {
        logger.error("[vite-zig] error: " + error);
      });
    }
  };
};

// vite.config.ts
defaultViteBuildOptions.modulePreload = false;
defaultViteBuildOptions.assetsDir = "";
defaultTerserOptions.mangle = {
  properties: {
    regex: /^_[a-z]/
  }
};
var js13kConfig = js13kViteConfig({
  roadrollerOptions: false,
  viteOptions: defaultViteBuildOptions,
  terserOptions: defaultTerserOptions
});
js13kConfig.rollupConfig = defaultRollupOptions;
js13kConfig.rollupConfig.output = {
  assetFileNames: "[name].[ext]",
  entryFileNames: "i.js",
  chunkFileNames: "[name].[ext]"
};
js13kConfig.base = "";
js13kConfig.server = { port: 8080, open: true };
js13kConfig.plugins.push(
  glsl({
    compress: true
  }),
  zig(),
  ViteMinifyPlugin({
    includeAutoGeneratedTags: true,
    removeAttributeQuotes: true,
    removeComments: true,
    removeRedundantAttributes: true,
    removeScriptTypeAttributes: true,
    removeStyleLinkTypeAttributes: true,
    sortClassName: true,
    useShortDoctype: true,
    collapseWhitespace: true,
    collapseInlineTagWhitespace: true,
    removeEmptyAttributes: true,
    removeOptionalTags: true,
    sortAttributes: true
  })
);
var vite_config_default = defineConfig(js13kConfig);
export {
  vite_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5jb25maWcudHMiLCAidml0ZS16aWcudHMiLCAid2FzbW9wdC50cyJdLAogICJzb3VyY2VzQ29udGVudCI6IFsiY29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2Rpcm5hbWUgPSBcIi9Vc2Vycy9lbGlhc2t1L2VrL2pzMTNrLTIwMjRcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9Vc2Vycy9lbGlhc2t1L2VrL2pzMTNrLTIwMjQvdml0ZS5jb25maWcudHNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfaW1wb3J0X21ldGFfdXJsID0gXCJmaWxlOi8vL1VzZXJzL2VsaWFza3UvZWsvanMxM2stMjAyNC92aXRlLmNvbmZpZy50c1wiO2ltcG9ydCB7XG4gIGpzMTNrVml0ZUNvbmZpZyxcbiAgZGVmYXVsdFZpdGVCdWlsZE9wdGlvbnMsXG4gIFJvYWRyb2xsZXJPcHRpb25zLFxuICBkZWZhdWx0Um9sbHVwT3B0aW9ucyxcbiAgZGVmYXVsdFRlcnNlck9wdGlvbnMsXG59IGZyb20gXCJqczEzay12aXRlLXBsdWdpbnNcIjtcbmltcG9ydCB7IGRlZmluZUNvbmZpZyB9IGZyb20gXCJ2aXRlXCI7XG5pbXBvcnQgeyBWaXRlTWluaWZ5UGx1Z2luIH0gZnJvbSBcInZpdGUtcGx1Z2luLW1pbmlmeVwiO1xuaW1wb3J0IGdsc2wgZnJvbSBcInZpdGUtcGx1Z2luLWdsc2xcIjtcbmltcG9ydCB7IHppZyB9IGZyb20gXCIuL3ZpdGUtemlnXCI7XG5cbi8vL2RlZmF1bHRWaXRlQnVpbGRPcHRpb25zLmFzc2V0c0lubGluZUxpbWl0ID0gMDtcbmRlZmF1bHRWaXRlQnVpbGRPcHRpb25zLm1vZHVsZVByZWxvYWQgPSBmYWxzZTtcbmRlZmF1bHRWaXRlQnVpbGRPcHRpb25zLmFzc2V0c0RpciA9IFwiXCI7XG5cbmRlZmF1bHRUZXJzZXJPcHRpb25zLm1hbmdsZSA9IHtcbiAgcHJvcGVydGllczoge1xuICAgIHJlZ2V4OiAvXl9bYS16XS8sXG4gIH0sXG59O1xuXG5jb25zdCBqczEza0NvbmZpZyA9IGpzMTNrVml0ZUNvbmZpZyh7XG4gIHJvYWRyb2xsZXJPcHRpb25zOiBmYWxzZSxcbiAgdml0ZU9wdGlvbnM6IGRlZmF1bHRWaXRlQnVpbGRPcHRpb25zLFxuICB0ZXJzZXJPcHRpb25zOiBkZWZhdWx0VGVyc2VyT3B0aW9ucyxcbn0pO1xuXG4oanMxM2tDb25maWcgYXMgYW55KS5yb2xsdXBDb25maWcgPSBkZWZhdWx0Um9sbHVwT3B0aW9ucztcbihqczEza0NvbmZpZyBhcyBhbnkpLnJvbGx1cENvbmZpZy5vdXRwdXQgPSB7XG4gIGFzc2V0RmlsZU5hbWVzOiBcIltuYW1lXS5bZXh0XVwiLFxuICBlbnRyeUZpbGVOYW1lczogXCJpLmpzXCIsXG4gIGNodW5rRmlsZU5hbWVzOiBcIltuYW1lXS5bZXh0XVwiLFxufTtcblxuKGpzMTNrQ29uZmlnIGFzIGFueSkuYmFzZSA9IFwiXCI7XG4oanMxM2tDb25maWcgYXMgYW55KS5zZXJ2ZXIgPSB7IHBvcnQ6IDgwODAsIG9wZW46IHRydWUgfTtcblxuKGpzMTNrQ29uZmlnIGFzIGFueSkucGx1Z2lucy5wdXNoKFxuICBnbHNsKHtcbiAgICBjb21wcmVzczogdHJ1ZSxcbiAgfSksXG4gIHppZygpLFxuICBWaXRlTWluaWZ5UGx1Z2luKHtcbiAgICBpbmNsdWRlQXV0b0dlbmVyYXRlZFRhZ3M6IHRydWUsXG4gICAgcmVtb3ZlQXR0cmlidXRlUXVvdGVzOiB0cnVlLFxuICAgIHJlbW92ZUNvbW1lbnRzOiB0cnVlLFxuICAgIHJlbW92ZVJlZHVuZGFudEF0dHJpYnV0ZXM6IHRydWUsXG4gICAgcmVtb3ZlU2NyaXB0VHlwZUF0dHJpYnV0ZXM6IHRydWUsXG4gICAgcmVtb3ZlU3R5bGVMaW5rVHlwZUF0dHJpYnV0ZXM6IHRydWUsXG4gICAgc29ydENsYXNzTmFtZTogdHJ1ZSxcbiAgICB1c2VTaG9ydERvY3R5cGU6IHRydWUsXG4gICAgY29sbGFwc2VXaGl0ZXNwYWNlOiB0cnVlLFxuICAgIGNvbGxhcHNlSW5saW5lVGFnV2hpdGVzcGFjZTogdHJ1ZSxcbiAgICByZW1vdmVFbXB0eUF0dHJpYnV0ZXM6IHRydWUsXG4gICAgcmVtb3ZlT3B0aW9uYWxUYWdzOiB0cnVlLFxuICAgIHNvcnRBdHRyaWJ1dGVzOiB0cnVlLFxuICB9KSxcbik7XG5cbmV4cG9ydCBkZWZhdWx0IGRlZmluZUNvbmZpZyhqczEza0NvbmZpZyk7XG4iLCAiY29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2Rpcm5hbWUgPSBcIi9Vc2Vycy9lbGlhc2t1L2VrL2pzMTNrLTIwMjRcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9Vc2Vycy9lbGlhc2t1L2VrL2pzMTNrLTIwMjQvdml0ZS16aWcudHNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfaW1wb3J0X21ldGFfdXJsID0gXCJmaWxlOi8vL1VzZXJzL2VsaWFza3UvZWsvanMxM2stMjAyNC92aXRlLXppZy50c1wiO2ltcG9ydCB7IExvZ2dlciwgUGx1Z2luIH0gZnJvbSBcInZpdGVcIjtcbmltcG9ydCB7IHNwYXduIH0gZnJvbSBcIm5vZGU6Y2hpbGRfcHJvY2Vzc1wiO1xuaW1wb3J0IHsgd2FzbW9wdCB9IGZyb20gXCIuL3dhc21vcHRcIjtcblxuZXhwb3J0IGludGVyZmFjZSBaaWdCdWlsZE9wdGlvbnMge1xuICAvLyBwYXRoIHRvIHppZyBzb3VyY2UtY29kZVxuICB3YXRjaD86IFJlZ0V4cDtcblxuICAvLyBQYXRoIHRvIGJ1aWxkLnppZ1xuICBidWlsZD86IHN0cmluZztcbn1cblxuY29uc3QgcnVuID0gKGNtZDogc3RyaW5nLCBhcmdzOiBzdHJpbmdbXSk6IFByb21pc2U8bnVtYmVyPiA9PiB7XG4gIGNvbnN0IGNoaWxkID0gc3Bhd24oY21kLCBhcmdzLCB7XG4gICAgc3RkaW86IFwiaW5oZXJpdFwiLFxuICB9KTtcblxuICByZXR1cm4gbmV3IFByb21pc2UoKHJlc29sdmUsIHJlamVjdCkgPT4ge1xuICAgIGNoaWxkLm9uKFwiZXJyb3JcIiwgcmVqZWN0KTtcbiAgICBjaGlsZC5vbihcImNsb3NlXCIsIHJlc29sdmUpO1xuICB9KTtcbn07XG5cbmV4cG9ydCBjb25zdCB6aWcgPSAob3B0aW9uczogWmlnQnVpbGRPcHRpb25zID0ge30pOiBQbHVnaW4gPT4ge1xuICBsZXQgbG9nZ2VyOiBMb2dnZXI7XG4gIGNvbnN0IGJ1aWxkOiBzdHJpbmcgPSBvcHRpb25zLmJ1aWxkID8/IFwiLi9idWlsZC56aWdcIjtcbiAgY29uc3Qgd2F0Y2g6IFJlZ0V4cCA9IG9wdGlvbnMud2F0Y2ggPz8gL14uK1xcLnppZyQvO1xuXG4gIC8vIGNoZWNrIGlmIGZpbGUgc2hvdWxkIGJlIHRyaWcgcmVjb21waWxhdGlvblxuICBjb25zdCBjaGVja0ZpbGUgPSAoZmlsZXBhdGg6IHN0cmluZykgPT4gd2F0Y2gudGVzdChmaWxlcGF0aCk7XG5cbiAgY29uc3QgcnVuQnVpbGQgPSBhc3luYyAoY29tbWFuZDogc3RyaW5nKSA9PiB7XG4gICAgY29uc3QgemlnID0gXCJ6aWdcIjtcbiAgICBsZXQgdHMgPSBwZXJmb3JtYW5jZS5ub3coKTtcbiAgICBsZXQgZXJyb3JzQ291bnQgPSAwO1xuXG4gICAgY29uc3QgYXJncyA9IFtcImJ1aWxkXCIsIFwiLS1zdW1tYXJ5XCIsIFwiYWxsXCIsIFwiLS1idWlsZC1maWxlXCIsIGJ1aWxkXTtcbiAgICBpZiAoY29tbWFuZCA9PT0gXCJidWlsZFwiKSB7XG4gICAgICBhcmdzLnB1c2goXCItRHJlbGVhc2U9dHJ1ZVwiKTtcbiAgICB9XG4gICAgY29uc3QgcmVzdWx0ID0gYXdhaXQgcnVuKHppZywgYXJncyk7XG4gICAgY29uc3QgY29tcGlsZUVycm9yID0gcmVzdWx0ICE9PSAwO1xuICAgIGlmIChjb21waWxlRXJyb3IpIHtcbiAgICAgICsrZXJyb3JzQ291bnQ7XG4gICAgfVxuICAgIGxvZ2dlci5pbmZvKGBbdml0ZS16aWddIGJ1aWxkIGlzIGRvbmUgJHsocGVyZm9ybWFuY2Uubm93KCkgLSB0cykgfCAwfSBtc2ApO1xuXG4gICAgaWYgKGNvbXBpbGVFcnJvcikge1xuICAgICAgbG9nZ2VyLmVycm9yKFwiW3ZpdGUtemlnXSBmYWlsZWQsIGNoZWNrIGNvbXBpbGUgZXJyb3JzXCIpO1xuICAgIH0gZWxzZSBpZiAoY29tbWFuZCA9PSBcImJ1aWxkXCIpIHtcbiAgICAgIHRyeSB7XG4gICAgICAgIGxldCB0cyA9IHBlcmZvcm1hbmNlLm5vdygpO1xuICAgICAgICBhd2FpdCB3YXNtb3B0KHtcbiAgICAgICAgICBmaWxlOiBcInppZy1vdXQvYmluL21haW4ud2FzbVwiLFxuICAgICAgICAgIGRpczogXCJ6aWctb3V0L2Jpbi9tYWluLndhc3RcIixcbiAgICAgICAgfSk7XG4gICAgICAgIGxvZ2dlci5pbmZvKFxuICAgICAgICAgIGBbd2FzbW9wdF0gb3B0aW1pemVkIGluICR7KHBlcmZvcm1hbmNlLm5vdygpIC0gdHMpIHwgMH0gbXNgLFxuICAgICAgICApO1xuICAgICAgfSBjYXRjaCAoZXJyKSB7XG4gICAgICAgIGxvZ2dlci53YXJuKGBbd2FzbW9wdF0gZXJyb3I6YCk7XG4gICAgICAgIGxvZ2dlci5lcnJvcihlcnIpO1xuICAgICAgfVxuICAgIH1cbiAgfTtcblxuICBsZXQgY2hhbmdlZCA9IHRydWU7XG4gIGxldCBidWlsZEluUHJvZ3Jlc3MgPSBmYWxzZTtcblxuICByZXR1cm4ge1xuICAgIG5hbWU6IFwiemlnXCIsXG4gICAgZW5mb3JjZTogXCJwcmVcIixcbiAgICBhc3luYyBjb25maWdSZXNvbHZlZChjb25maWcpIHtcbiAgICAgIGxvZ2dlciA9IGNvbmZpZy5sb2dnZXI7XG4gICAgICBpZiAoY29uZmlnLmNvbW1hbmQgPT09IFwic2VydmVcIikge1xuICAgICAgICBzZXRJbnRlcnZhbChhc3luYyAoKSA9PiB7XG4gICAgICAgICAgaWYgKGNoYW5nZWQgJiYgIWJ1aWxkSW5Qcm9ncmVzcykge1xuICAgICAgICAgICAgY2hhbmdlZCA9IGZhbHNlO1xuICAgICAgICAgICAgYnVpbGRJblByb2dyZXNzID0gdHJ1ZTtcbiAgICAgICAgICAgIGF3YWl0IHJ1bkJ1aWxkKGNvbmZpZy5jb21tYW5kKTtcbiAgICAgICAgICAgIGJ1aWxkSW5Qcm9ncmVzcyA9IGZhbHNlO1xuICAgICAgICAgIH1cbiAgICAgICAgfSwgMjAwKTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIGF3YWl0IHJ1bkJ1aWxkKGNvbmZpZy5jb21tYW5kKTtcbiAgICAgIH1cbiAgICB9LFxuICAgIGFzeW5jIGNvbmZpZ3VyZVNlcnZlcihzZXJ2ZXIpIHtcbiAgICAgIHNlcnZlci53YXRjaGVyXG4gICAgICAgIC5vbihcImFkZFwiLCAoZmlsZXBhdGgpID0+IHtcbiAgICAgICAgICBpZiAoY2hlY2tGaWxlKGZpbGVwYXRoKSkge1xuICAgICAgICAgICAgbG9nZ2VyLmluZm8oXCJbdml0ZS16aWddIGZpbGUgaXMgYWRkZWQ6IFwiICsgZmlsZXBhdGgpO1xuICAgICAgICAgICAgY2hhbmdlZCA9IHRydWU7XG4gICAgICAgICAgfVxuICAgICAgICB9KVxuICAgICAgICAub24oXCJjaGFuZ2VcIiwgKGZpbGVwYXRoKSA9PiB7XG4gICAgICAgICAgaWYgKGNoZWNrRmlsZShmaWxlcGF0aCkpIHtcbiAgICAgICAgICAgIGxvZ2dlci5pbmZvKFwiW3ZpdGUtemlnXSBmaWxlIGlzIGNoYW5nZWQ6IFwiICsgZmlsZXBhdGgpO1xuICAgICAgICAgICAgY2hhbmdlZCA9IHRydWU7XG4gICAgICAgICAgfVxuICAgICAgICB9KVxuICAgICAgICAub24oXCJ1bmxpbmtcIiwgKGZpbGVwYXRoKSA9PiB7XG4gICAgICAgICAgaWYgKGNoZWNrRmlsZShmaWxlcGF0aCkpIHtcbiAgICAgICAgICAgIGxvZ2dlci5pbmZvKFwiW3ZpdGUtemlnXSBmaWxlIGlzIHJlbW92ZWQ6IFwiICsgZmlsZXBhdGgpO1xuICAgICAgICAgICAgY2hhbmdlZCA9IHRydWU7XG4gICAgICAgICAgfVxuICAgICAgICB9KVxuICAgICAgICAub24oXCJlcnJvclwiLCAoZXJyb3IpID0+IHtcbiAgICAgICAgICBsb2dnZXIuZXJyb3IoXCJbdml0ZS16aWddIGVycm9yOiBcIiArIGVycm9yKTtcbiAgICAgICAgfSk7XG4gICAgfSxcbiAgfTtcbn07XG4iLCAiY29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2Rpcm5hbWUgPSBcIi9Vc2Vycy9lbGlhc2t1L2VrL2pzMTNrLTIwMjRcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfZmlsZW5hbWUgPSBcIi9Vc2Vycy9lbGlhc2t1L2VrL2pzMTNrLTIwMjQvd2FzbW9wdC50c1wiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9pbXBvcnRfbWV0YV91cmwgPSBcImZpbGU6Ly8vVXNlcnMvZWxpYXNrdS9lay9qczEzay0yMDI0L3dhc21vcHQudHNcIjtpbXBvcnQgeyBkaXJuYW1lLCBiYXNlbmFtZSwgam9pbiB9IGZyb20gXCJub2RlOnBhdGhcIjtcbmltcG9ydCB7IHNwYXduLCBleGVjU3luYywgZXhlY0ZpbGVTeW5jIH0gZnJvbSBcIm5vZGU6Y2hpbGRfcHJvY2Vzc1wiO1xuaW1wb3J0ICogYXMgRlMgZnJvbSBcIm5vZGU6ZnMvcHJvbWlzZXNcIjtcblxuZXhwb3J0IGludGVyZmFjZSBXYXNtT3B0T3B0aW9ucyB7XG4gIGZpbGU6IHN0cmluZztcbiAgZGlzPzogc3RyaW5nO1xufVxuXG5jb25zdCBydW4gPSAoY21kOiBzdHJpbmcsIGFyZ3M6IHN0cmluZ1tdKTogUHJvbWlzZTxudW1iZXI+ID0+IHtcbiAgY29uc3QgY2hpbGQgPSBzcGF3bihjbWQsIGFyZ3MsIHtcbiAgICBzdGRpbzogXCJpbmhlcml0XCIsXG4gIH0pO1xuICByZXR1cm4gbmV3IFByb21pc2UoKHJlc29sdmUsIHJlamVjdCkgPT4ge1xuICAgIGNoaWxkLm9uKFwiZXJyb3JcIiwgcmVqZWN0KTtcbiAgICBjaGlsZC5vbihcImNsb3NlXCIsIHJlc29sdmUpO1xuICB9KTtcbn07XG5cbmV4cG9ydCBjb25zdCB3YXNtb3B0ID0gYXN5bmMgKG9wdGlvbnM6IFdhc21PcHRPcHRpb25zKSA9PiB7XG4gIGNvbnN0IGlucHV0V2FzbVNpemUgPSAoYXdhaXQgRlMuc3RhdChvcHRpb25zLmZpbGUpKS5zaXplO1xuICBjb25zb2xlLmluZm8oXCJJbnB1dCBXQVNNIHNpemU6XCIsIGlucHV0V2FzbVNpemUpO1xuXG4gIGNvbnN0IGJpbmFyeWVuID0gcHJvY2Vzcy5lbnYuQklOQVJZRU5fUk9PVDtcbiAgY29uc3QgYnVpbGREaXIgPSBkaXJuYW1lKG9wdGlvbnMuZmlsZSk7XG4gIGNvbnN0IG5hbWUgPSBiYXNlbmFtZShvcHRpb25zLmZpbGUsIFwiLndhc21cIik7XG4gIGNvbnN0IG9wdEZsYWdzID0gW1wiLU9zXCIsIFwiLU96XCIsIFwiLU9cIiwgXCItTzJcIiwgXCItTzNcIiwgXCItTzRcIl07XG4gIGNvbnN0IHBhc3NGbGFncyA9IChvcHQ6IHN0cmluZykgPT4gW1xuICAgIC8vIFwiLWNcIixcbiAgICAvL1wiLS1zaHJpbmstbGV2ZWw9MTAwMDBcIixcbiAgICAvLyBcIi0tYXZvaWQtcmVpbnRlcnByZXRzXCIsXG4gICAgLy8gXCItLWlnbm9yZS1pbXBsaWNpdC10cmFwc1wiLFxuICAgIC8vIFwiLS10cmFwcy1uZXZlci1oYXBwZW5cIixcbiAgICAvLyBcIi0tZmFzdC1tYXRoXCIsXG4gICAgLy8gXCItLXplcm8tZmlsbGVkLW1lbW9yeVwiLFxuICAgIC8vIFwiLS1jbG9zZWQtd29ybGRcIixcbiAgICAvLyBcIi0tZGlzYWJsZS1zaWduLWV4dFwiLFxuICAgIC8vIFwiLS1kY2VcIixcbiAgICAvLyBcIi0tc2ltcGxpZnktZ2xvYmFscy1vcHRpbWl6aW5nXCIsXG4gICAgLy8gXCItLXNpbXBsaWZ5LWxvY2Fscy1ub3RlZVwiLFxuICAgIC8vXCItLWFsaWdubWVudC1sb3dlcmluZ1wiLFxuICAgIC8vXCItLWRlYWxpZ25cIixcbiAgICAvLyBcIi0tbWVtb3J5LXBhY2tpbmdcIixcbiAgICAvLyBcIi0tb3B0aW1pemUtY2FzdHNcIixcbiAgICAvLyBcIi0tYWx3YXlzLWlubGluZS1tYXgtZnVuY3Rpb24tc2l6ZT0wXCIsXG4gICAgLy8gXCItLWZsZXhpYmxlLWlubGluZS1tYXgtZnVuY3Rpb24tc2l6ZT0wXCJcbiAgICAvL1wiLU96XCIsXG4gICAgXCItLWNvbnZlcmdlXCIsXG4gICAgXCItLWxvdy1tZW1vcnktdW51c2VkXCIsXG4gICAgb3B0LFxuICAgIFwiLXRuaFwiLFxuICAgIFwiLS1lbmFibGUtbm9udHJhcHBpbmctZmxvYXQtdG8taW50XCIsXG4gICAgLy8gXCItLWVuYWJsZS1zaW1kXCIsXG4gICAgLy8gXCItLWVuYWJsZS1zaWduLWV4dFwiLFxuICAgIFwiLS1lbmFibGUtYnVsay1tZW1vcnlcIixcbiAgICAvLyBcIi0tZW5hYmxlLW11dGFibGUtZ2xvYmFsc1wiLFxuICAgIC8vIFwiLS1lbmFibGUtbXVsdGl2YWx1ZVwiLFxuICAgIC8vIFwiLS1lbmFibGUtZXh0ZW5kZWQtY29uc3RcIixcbiAgICBcIi0tZmFzdC1tYXRoXCIsXG4gICAgLy9cIi0tZ2VuZXJhdGUtZ2xvYmFsLWVmZmVjdHNcIiwgXCItT3pcIixcbiAgICAvLyBwYXNzZXM6XG4gICAgXCItTzRcIixcbiAgICBcIi0tZ3VmYVwiLFxuICAgIFwiLS1mbGF0dGVuXCIsXG4gICAgXCItLXJlcmVsb29wXCIsXG4gICAgLy8gXCItLWk2NC10by1pMzItbG93ZXJpbmdcIixcbiAgICBvcHQsXG4gICAgXCItLWludHJpbnNpYy1sb3dlcmluZ1wiLFxuICAgIC8vIFwiLS1tZW1vcnktcGFja2luZ1wiLFxuICAgIFwiLS1wcmVjb21wdXRlLXByb3BhZ2F0ZVwiLFxuICAgIFwiLS1hdm9pZC1yZWludGVycHJldHNcIixcbiAgICBcIi0tdW50ZWVcIixcbiAgICBcIi0tdmFjdXVtXCIsXG4gICAgXCItLWNmcFwiLFxuICAgIC8vIFwiLS1vcHRpbWl6ZS1jYXN0c1wiLFxuICAgIC8vIFwiLS1vcHRpbWl6ZS1pbnN0cnVjdGlvbnNcIixcbiAgICAvLyBcIi0tZGFlXCIsXG4gICAgLy8gXCItLWRhZS1vcHRpbWl6aW5nXCIsXG4gIF07XG4gIC8vIFx1MDQzRlx1MDQzNVx1MDQ0MFx1MDQzNVx1MDQzQlx1MDQzOFx1MDQzRFx1MDQzQVx1MDQ0M1x1MDQzNVx1MDQzQyB3YXNtIFx1MDQ0MSBcdTA0NDBcdTA0MzBcdTA0MzdcdTA0M0JcdTA0MzhcdTA0NDdcdTA0M0RcdTA0NEJcdTA0M0NcdTA0MzggXHUwNDNFXHUwNDNGXHUwNDQ2XHUwNDM4XHUwNDRGXHUwNDNDXHUwNDM4IFx1MDQzRVx1MDQzRlx1MDQ0Mlx1MDQzOFx1MDQzQ1x1MDQzOFx1MDQzN1x1MDQzMFx1MDQ0Nlx1MDQzOFx1MDQzOFxuICBjb25zdCBmaWxlcyA9IGF3YWl0IFByb21pc2UuYWxsKFxuICAgIG9wdEZsYWdzLm1hcChhc3luYyAocmVsaW5rRmxhZykgPT4ge1xuICAgICAgY29uc3QgZmlsZXBhdGggPSBgJHtidWlsZERpcn0vJHtuYW1lfSR7cmVsaW5rRmxhZ30ud2FzbWA7XG4gICAgICBhd2FpdCBydW4oYCR7YmluYXJ5ZW59L2Jpbi93YXNtLW9wdGAsIFtcbiAgICAgICAgLi4ucGFzc0ZsYWdzKHJlbGlua0ZsYWcpLFxuICAgICAgICByZWxpbmtGbGFnLFxuICAgICAgICBgJHtidWlsZERpcn0vJHtuYW1lfS53YXNtYCxcbiAgICAgICAgYC1vYCxcbiAgICAgICAgZmlsZXBhdGgsXG4gICAgICBdKTtcbiAgICAgIHJldHVybiBhd2FpdCBGUy5zdGF0KGZpbGVwYXRoKTtcbiAgICB9KSxcbiAgKTtcblxuICAvLyBcdTA0M0RcdTA0MzBcdTA0MzlcdTA0MzRcdTA0MzVcdTA0M0MgXHUwNDQ0XHUwNDMwXHUwNDM5XHUwNDNCIFx1MDQ0MSBcdTA0M0NcdTA0MzVcdTA0M0RcdTA0NENcdTA0NDhcdTA0MzhcdTA0M0MgXHUwNDQwXHUwNDMwXHUwNDM3XHUwNDNDXHUwNDM1XHUwNDQwXHUwNDNFXHUwNDNDIFx1MDQzOCBcdTA0MzJcdTA0NEJcdTA0MzFcdTA0MzVcdTA0NDBcdTA0MzVcdTA0M0MgXHUwNDM1XHUwNDMzXHUwNDNFXG4gIGxldCBtaW5TaXplID0gMHg3ZmZmZmZmZjtcbiAgbGV0IG1pbkZpbGU6IHN0cmluZyB8IHVuZGVmaW5lZDtcbiAgbGV0IGJlc3RGbGFnOiBzdHJpbmcgfCB1bmRlZmluZWQ7XG4gIGNvbnN0IGFkdnppcCA9IFwiYWR2emlwXCI7XG4gIGNvbnN0IHRlbXBGaWxlczogc3RyaW5nW10gPSBbXTtcbiAgZm9yIChsZXQgaSA9IDA7IGkgPCBvcHRGbGFncy5sZW5ndGg7ICsraSkge1xuICAgIGNvbnN0IG9wdEZsYWcgPSBvcHRGbGFnc1tpXTtcbiAgICBjb25zdCBvcHRGaWxlID0gYCR7YnVpbGREaXJ9LyR7bmFtZX0ke29wdEZsYWd9Lndhc21gO1xuICAgIGNvbnN0IHdhc21TaXplID0gZmlsZXNbaV0uc2l6ZTtcbiAgICBjb25zdCB6aXBmaWxlbmFtZSA9IGAke2J1aWxkRGlyfS8ke25hbWV9JHtvcHRGbGFnfS53YXNtLnppcGA7XG4gICAgY29uc3QgcmVzdWx0ID0gZXhlY0ZpbGVTeW5jKGFkdnppcCwgW1xuICAgICAgXCItLXNocmluay1pbnNhbmVcIixcbiAgICAgIFwiLWFcIixcbiAgICAgIHppcGZpbGVuYW1lLFxuICAgICAgb3B0RmlsZSxcbiAgICBdKTtcbiAgICB0ZW1wRmlsZXMucHVzaChvcHRGaWxlLCB6aXBmaWxlbmFtZSk7XG4gICAgY29uc3QgemlwcGVkU2l6ZSA9IChhd2FpdCBGUy5zdGF0KHppcGZpbGVuYW1lKSkuc2l6ZTtcbiAgICBjb25zb2xlLmluZm8oYCR7b3B0RmxhZ30gOiAke3dhc21TaXplfSBieXRlcyA+PiAke3ppcHBlZFNpemV9YCk7XG5cbiAgICBpZiAoemlwcGVkU2l6ZSA8IG1pblNpemUpIHtcbiAgICAgIGJlc3RGbGFnID0gb3B0RmxhZztcbiAgICAgIG1pblNpemUgPSB6aXBwZWRTaXplO1xuICAgICAgbWluRmlsZSA9IG9wdEZpbGU7XG4gICAgfVxuICB9XG4gIGlmIChtaW5GaWxlKSB7XG4gICAgYXdhaXQgRlMuY29weUZpbGUobWluRmlsZSwgYCR7YnVpbGREaXJ9LyR7bmFtZX0ud2FzbWApO1xuICAgIGNvbnNvbGUuaW5mbyhcIldBU00gU0laRTogXCIgKyBtaW5TaXplICsgXCIgYnl0ZXNcIiArIFwiIChcIiArIGJlc3RGbGFnICsgXCIpXCIpO1xuICB9XG4gIGF3YWl0IFByb21pc2UuYWxsKHRlbXBGaWxlcy5tYXAoKGZpbGVwYXRoKSA9PiBGUy51bmxpbmsoZmlsZXBhdGgpKSk7XG4gIGlmIChvcHRpb25zLmRpcykge1xuICAgIGF3YWl0IHJ1bihqb2luKGJpbmFyeWVuLCBcImJpbi93YXNtLWRpc1wiKSwgW1xuICAgICAgXCItb1wiLFxuICAgICAgb3B0aW9ucy5kaXMsXG4gICAgICBgJHtidWlsZERpcn0vJHtuYW1lfS53YXNtYCxcbiAgICBdKTtcbiAgfVxufTtcbiJdLAogICJtYXBwaW5ncyI6ICI7QUFBc1E7QUFBQSxFQUNwUTtBQUFBLEVBQ0E7QUFBQSxFQUVBO0FBQUEsRUFDQTtBQUFBLE9BQ0s7QUFDUCxTQUFTLG9CQUFvQjtBQUM3QixTQUFTLHdCQUF3QjtBQUNqQyxPQUFPLFVBQVU7OztBQ1JqQixTQUFTLFNBQUFBLGNBQWE7OztBQ0R3TyxTQUFTLFNBQVMsVUFBVSxZQUFZO0FBQ3RTLFNBQVMsT0FBaUIsb0JBQW9CO0FBQzlDLFlBQVksUUFBUTtBQU9wQixJQUFNLE1BQU0sQ0FBQyxLQUFhLFNBQW9DO0FBQzVELFFBQU0sUUFBUSxNQUFNLEtBQUssTUFBTTtBQUFBLElBQzdCLE9BQU87QUFBQSxFQUNULENBQUM7QUFDRCxTQUFPLElBQUksUUFBUSxDQUFDLFNBQVMsV0FBVztBQUN0QyxVQUFNLEdBQUcsU0FBUyxNQUFNO0FBQ3hCLFVBQU0sR0FBRyxTQUFTLE9BQU87QUFBQSxFQUMzQixDQUFDO0FBQ0g7QUFFTyxJQUFNLFVBQVUsT0FBTyxZQUE0QjtBQUN4RCxRQUFNLGlCQUFpQixNQUFTLFFBQUssUUFBUSxJQUFJLEdBQUc7QUFDcEQsVUFBUSxLQUFLLG9CQUFvQixhQUFhO0FBRTlDLFFBQU0sV0FBVyxRQUFRLElBQUk7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QUNsQyxtQkFBbUI7QUFBQSxFQUNuQixhQUFhO0FBQUEsRUFDYixlQUFlO0FBQ2pCLENBQUM7QUFFQSxZQUFvQixlQUFlO0FBQ25DLFlBQW9CLGFBQWEsU0FBUztBQUFBLEVBQ3pDLGdCQUFnQjtBQUFBLEVBQ2hCLGdCQUFnQjtBQUFBLEVBQ2hCLGdCQUFnQjtBQUNsQjtBQUVDLFlBQW9CLE9BQU87QUFDM0IsWUFBb0IsU0FBUyxFQUFFLE1BQU0sTUFBTSxNQUFNLEtBQUs7QUFFdEQsWUFBb0IsUUFBUTtBQUFBLEVBQzNCLEtBQUs7QUFBQSxJQUNILFVBQVU7QUFBQSxFQUNaLENBQUM7QUFBQSxFQUNELElBQUk7QUFBQSxFQUNKLGlCQUFpQjtBQUFBLElBQ2YsMEJBQTBCO0FBQUEsSUFDMUIsdUJBQXVCO0FBQUEsSUFDdkIsZ0JBQWdCO0FBQUEsSUFDaEIsMkJBQTJCO0FBQUEsSUFDM0IsNEJBQTRCO0FBQUEsSUFDNUIsK0JBQStCO0FBQUEsSUFDL0IsZUFBZTtBQUFBLElBQ2YsaUJBQWlCO0FBQUEsSUFDakIsb0JBQW9CO0FBQUEsSUFDcEIsNkJBQTZCO0FBQUEsSUFDN0IsdUJBQXVCO0FBQUEsSUFDdkIsb0JBQW9CO0FBQUEsSUFDcEIsZ0JBQWdCO0FBQUEsRUFDbEIsQ0FBQztBQUNIO0FBRUEsSUFBTyxzQkFBUSxhQUFhLFdBQVc7IiwKICAibmFtZXMiOiBbInNwYXduIiwgInJ1biIsICJzcGF3biIsICJ6aWciLCAidHMiXQp9Cg==
