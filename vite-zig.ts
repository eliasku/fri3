import { Logger, Plugin } from "vite";
import { spawn } from "node:child_process";
import { wasmopt } from "./wasmopt";

export interface ZigBuildOptions {
  // path to zig source-code
  watch?: RegExp;

  // Path to build.zig
  build?: string;
}

const run = (cmd: string, args: string[]): Promise<number> => {
  const child = spawn(cmd, args, {
    stdio: "inherit",
  });

  return new Promise((resolve, reject) => {
    child.on("error", reject);
    child.on("close", resolve);
  });
};

export const zig = (options: ZigBuildOptions = {}): Plugin => {
  let logger: Logger;
  const build: string = options.build ?? "./build.zig";
  const watch: RegExp = options.watch ?? /^.+\.zig$/;

  // check if file should be trig recompilation
  const checkFile = (filepath: string) => watch.test(filepath);

  const runBuild = async (command: string) => {
    const zig = "zig";
    let ts = performance.now();
    let errorsCount = 0;

    const args = ["build", "--summary", "all", "--build-file", build];
    if (command === "build") {
      args.push("-Drelease=true");
    }
    const result = await run(zig, args);
    const compileError = result !== 0;
    if (compileError) {
      ++errorsCount;
    }
    logger.info(`[vite-zig] build is done ${(performance.now() - ts) | 0} ms`);

    if (compileError) {
      logger.error("[vite-zig] failed, check compile errors");
    } else if (command == "build") {
      try {
        let ts = performance.now();
        await wasmopt({
          file: "zig-out/bin/main.wasm",
          dis: "zig-out/bin/main.wast",
        });
        logger.info(
          `[wasmopt] optimized in ${(performance.now() - ts) | 0} ms`,
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
      server.watcher
        .on("add", (filepath) => {
          if (checkFile(filepath)) {
            logger.info("[vite-zig] file is added: " + filepath);
            changed = true;
          }
        })
        .on("change", (filepath) => {
          if (checkFile(filepath)) {
            logger.info("[vite-zig] file is changed: " + filepath);
            changed = true;
          }
        })
        .on("unlink", (filepath) => {
          if (checkFile(filepath)) {
            logger.info("[vite-zig] file is removed: " + filepath);
            changed = true;
          }
        })
        .on("error", (error) => {
          logger.error("[vite-zig] error: " + error);
        });
    },
  };
};
