import * as fs from "node:fs/promises";

const zigExports: Record<string, any> = {
  onFrameRequest: {},
  onPointerEvent: {},
  onKeyboardEvent: {},
};

const imports: Record<string, any> = {
  drawTriangles: {
    sig: "(vb: [*]const u8, vb_size: u32, ib: [*]const u16, indices_count: u32, handle: u32) void",
  },
  playUserAudioBuffer: {
    sig: "(samples: [*]const f32, length: u32, vol: f32, pan: f32, note: f32, when: f32) void",
  },
  setupPass: {
    sig: "(id: u32) void",
  },
  sin: {
    sig: "(x: f32) f32",
  },
  cos: {
    sig: "(x: f32) f32",
  },
  pow: {
    sig: "(x: f32, y: f32) f32",
  },
  atan2: {
    sig: "(x: f32, y: f32) f32",
  },
  text: {
    sig: "(handle: i32, x: i32, y: i32, color: u32, size: i32, msg_ptr: [*]const u8, msg_len: usize) void",
  },
};

let i = 0;
for (const [k, v] of Object.entries(zigExports)) {
  zigExports[k].id = String.fromCharCode("a".charCodeAt(0) + i);
  ++i;
}

i = 0;
for (const [k, v] of Object.entries(imports)) {
  imports[k].id = String.fromCharCode("a".charCodeAt(0) + i);
  ++i;
}

////////

const tsImportCodeBlock = () =>
  Object.entries(zigExports)
    .map(([k, v]) => `\n\t_${k}: exports.${v.id} as any,`)
    .join("");

const tsExportCodeBlock = () =>
  Object.entries(imports)
    .map(([k, v]) => `\n\t\t${v.id}: _${k},`)
    .join("");

const run = async () => {
  await fs.writeFile(
    "ts/_bridge.ts",
    `
export const importZigFunctions = (exports: WebAssembly.Exports) => ({${tsImportCodeBlock()}
    _memory: exports.memory as WebAssembly.Memory,
});

export type ExportMap = {${Object.entries(imports)
      .map(([k, v]) => `\n\t_${k}: Function,`)
      .join("")}
};

export const createExportMap = ({${Object.entries(imports)
      .map(([k, v]) => `\n\t_${k},`)
      .join("")}
}: ExportMap) => ({
    "0": {${tsExportCodeBlock()}
    },
});
`,
    "utf8",
  );

  await fs.writeFile(
    "zig/gain/_bridge.zig",
    `
const builtin = @import("builtin");

pub const enabled = builtin.cpu.arch == .wasm32 and builtin.os.tag == .freestanding;

pub const identifiers = .{${Object.entries(zigExports)
      .map(([k, v]) => `\n\t"${v.id}", // _${k}`)
      .join("")}
};

pub fn declareExports(comptime functions: type) void {${Object.entries(
      zigExports,
    )
      .map(([k, v]) => `\n\t@export(functions.${k}, .{ .name = "${v.id}" });`)
      .join("")}
}

pub const Imports = if (enabled) struct {${Object.entries(imports)
      .map(
        ([k, v]) => `\n\textern "0" fn ${v.id}${v.sig};
\tpub const ${k} = ${v.id};\n`,
      )
      .join("")}
    pub const enabled = true;
} else struct {
    pub const enabled = false;
};
`,
    "utf8",
  );
};

run();
