import { dirname, basename, join } from "node:path";
import { spawn, execSync, execFileSync } from "node:child_process";
import * as FS from "node:fs/promises";

export interface WasmOptOptions {
  file: string;
  dis?: string;
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

export const wasmopt = async (options: WasmOptOptions) => {
  const inputWasmSize = (await FS.stat(options.file)).size;
  console.info("Input WASM size:", inputWasmSize);

  const binaryen = process.env.BINARYEN_ROOT;
  const buildDir = dirname(options.file);
  const name = basename(options.file, ".wasm");
  const optFlags = ["-Os", "-Oz", "-O", "-O2", "-O3", "-O4"];
  const passFlags = (opt: string) => [
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
    "--cfp",
    // "--optimize-casts",
    // "--optimize-instructions",
    // "--dae",
    // "--dae-optimizing",
  ];
  // перелинкуем wasm с различными опциями оптимизации
  const files = await Promise.all(
    optFlags.map(async (relinkFlag) => {
      const filepath = `${buildDir}/${name}${relinkFlag}.wasm`;
      await run(`${binaryen}/bin/wasm-opt`, [
        ...passFlags(relinkFlag),
        relinkFlag,
        `${buildDir}/${name}.wasm`,
        `-o`,
        filepath,
      ]);
      return await FS.stat(filepath);
    }),
  );

  // найдем файл с меньшим размером и выберем его
  let minSize = 0x7fffffff;
  let minFile: string | undefined;
  let bestFlag: string | undefined;
  const advzip = "advzip";
  const tempFiles: string[] = [];
  for (let i = 0; i < optFlags.length; ++i) {
    const optFlag = optFlags[i];
    const optFile = `${buildDir}/${name}${optFlag}.wasm`;
    const wasmSize = files[i].size;
    const zipfilename = `${buildDir}/${name}${optFlag}.wasm.zip`;
    const result = execFileSync(advzip, [
      "--shrink-insane",
      "-a",
      zipfilename,
      optFile,
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
    console.info("WASM SIZE: " + minSize + " bytes" + " (" + bestFlag + ")");
  }
  await Promise.all(tempFiles.map((filepath) => FS.unlink(filepath)));
  if (options.dis) {
    await run(join(binaryen, "bin/wasm-dis"), [
      "-o",
      options.dis,
      `${buildDir}/${name}.wasm`,
    ]);
  }
};
