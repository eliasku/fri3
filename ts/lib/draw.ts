import { MEM } from "./base/mem";
import { opaqueProgram } from "../shaders/opaque";
import { blendProgram } from "../shaders/blend";
import { Program, bindAttrib } from "../shaders/program";
import { GL, gl } from "./base/webgl";
import { addRenderStats } from "./dev/stats";

export const calcOrtho2D = (w: number, h: number) => [
  2 / w,
  0,
  0,
  0,
  0,
  -2 / h,
  0,
  0,
  0,
  0,
  /* -(1.0 / DEPTH) */ -1e-5,
  0,
  -1,
  1,
  0,
  1,
];

export const beginFrame = (w: number, h: number) => {
  gl.viewport(0, 0, w, h);
  // defaults:
  // gl.clearDepth(1);
  gl.clear(GL.DEPTH_BUFFER_BIT);

  setupViewport2d(w, h);
};

let mvp: number[];
let viewportW: number;
let viewportH: number;

const setupViewport2d = (w: number, h: number) => {
  viewportW = w;
  viewportH = h;
  mvp = calcOrtho2D(w, h);
};

let currentProgram: Program;
const setupProgram = (program: Program) => {
  gl.useProgram(program._instance);
  gl.uniformMatrix4fv(program._uMVP, false, mvp);
  if (program._uImage0) {
    gl.uniform1i(program._uImage0, 0);
  }
  if (program._uResolution) {
    gl.uniform2f(program._uResolution, viewportW, viewportH);
  }
  currentProgram = program;
};

export const setupOpaquePass = () => {
  setupProgram(opaqueProgram);
  gl.disable(GL.BLEND);
  gl.enable(GL.DEPTH_TEST);
  gl.depthFunc(GL.LESS);
  gl.depthMask(true);
  // defaults:
  // gl.clearDepth(1);
  // gl.depthRange(0, 1);
};

export const setupBlendPass = () => {
  setupProgram(blendProgram);
  gl.enable(GL.BLEND);
  gl.blendFunc(GL.ONE, GL.ONE_MINUS_SRC_ALPHA);
  gl.enable(GL.DEPTH_TEST);
  gl.depthFunc(GL.LEQUAL);
  gl.depthMask(false);
};

const dynamicBuffers: WebGLBuffer[] = [];

export const drawTriangles = (
  vb: Ptr<void>,
  vb_size: u32,
  ib: Ptr<u16>,
  indices_count: u32,
  handle: u32,
): void => {
  const i = handle++;
  const j = handle++;
  if (!dynamicBuffers[i]) {
    dynamicBuffers[i] = gl.createBuffer()!;
    dynamicBuffers[j] = gl.createBuffer()!;
  }
  // bind buffers to program
  const vertexByteSize = (3 + 2 + 1 + 1) << 2;

  // select buffers
  gl.bindBuffer(GL.ARRAY_BUFFER, dynamicBuffers[i]);
  gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, dynamicBuffers[j]);

  // upload buffers data
  gl.bufferData(
    GL.ARRAY_BUFFER,
    new Uint8Array(MEM.buffer, vb, vb_size),
    GL.STREAM_DRAW,
  );
  gl.bufferData(
    GL.ELEMENT_ARRAY_BUFFER,
    new Uint16Array(MEM.buffer, ib, indices_count),
    GL.STREAM_DRAW,
  );

  // bind buffers to program
  bindAttrib(currentProgram._aPosition, 3, vertexByteSize, 0, GL.FLOAT, false);
  bindAttrib(currentProgram._aTexCoord, 2, vertexByteSize, 12, GL.FLOAT, false);
  bindAttrib(
    currentProgram._aColorMul,
    4,
    vertexByteSize,
    20,
    GL.UNSIGNED_BYTE,
    true,
  );
  bindAttrib(
    currentProgram._aColorAdd,
    4,
    vertexByteSize,
    24,
    GL.UNSIGNED_BYTE,
    true,
  );

  // draw triangles
  gl.drawElements(GL.TRIANGLES, indices_count, GL.UNSIGNED_SHORT, 0);

  if (import.meta.env.DEV) {
    if (0) {
      // TODO: debug GL option
      const err = gl.getError();
      if (err) {
        console.error("gl error");
      }
    }
    addRenderStats(vb_size / vertexByteSize, indices_count, handle);
  }
};
