import {
  beginFrame,
  drawTriangles,
  setupBlendPass,
  setupOpaquePass,
} from "./draw";
import { gl } from "./base/webgl";
import { playUserAudioBuffer } from "./base/audio";
import { setupInput } from "./base/input";
import { MEM, decodeText, initMemoryObjects } from "./base/mem";
import { __setTexture, __setTextureData } from "./texture";
import { addStatsView, updateStatsText } from "./dev/stats";
import { createExportMap, importZigFunctions } from "../_bridge";
import { drawText } from "./font";

let { sin, cos, pow, atan2 } = Math;

export const importMap = createExportMap({
  _log: (ptr: Ptr<u8>, len: usize) => {
    console.log(decodeText(ptr, len));
  },
  _drawTriangles: drawTriangles,
  _playUserAudioBuffer: playUserAudioBuffer,
  _setTexture: __setTexture,
  _setTextureData: __setTextureData,
  _setupPass: (id: u32): void => (id ? setupBlendPass() : setupOpaquePass()),
  _drawText: drawText,
  _sin: sin,
  _cos: cos,
  _pow: pow,
  _atan2: atan2,
});

export const run = (instance: WebAssembly.Instance) => {
  if (import.meta.env.DEV) {
    addStatsView();
  }

  let zig = importZigFunctions(instance.exports);
  initMemoryObjects(zig._memory);
  setupInput(zig._onPointerEvent, zig._onKeyboardEvent);

  let raf = requestAnimationFrame;
  let accum = 0;
  let prev = performance.now();
  const onFrame = (ts: DOMHighResTimeStamp) => {
    accum += ts - prev;
    prev = ts;
    let steps = accum >> 3;
    accum -= steps << 3;
    if (steps) {
      const w = gl.drawingBufferWidth;
      const h = gl.drawingBufferHeight;
      beginFrame(w, h);
      zig._onFrameRequest(steps, w, h);
      if (import.meta.env.DEV) {
        updateStatsText(ts);
      }
    }
    raf(onFrame);
  };
  raf(onFrame);
};
