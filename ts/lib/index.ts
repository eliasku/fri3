import {
  beginFrame,
  drawTriangles,
  setupBlendPass,
  setupOpaquePass,
} from "./draw";
import { gl } from "./base/webgl";
import { playUserAudioBuffer } from "./base/audio";
import { setupInput } from "./base/input";
import { decodeText, initMemoryObjects } from "./base/mem";
import { addStatsView, updateStatsText } from "./dev/stats";
import { createExportMap, importZigFunctions } from "../_bridge";
import { text } from "./text";

let { sin, cos, pow, atan2 } = Math;

export const importMap = createExportMap({
  _text: (handle: i32, x: i32, y: i32, color: u32, size: f32, ptr: Ptr<u8>, len: usize) => text(handle, x, y, color, size, decodeText(ptr, len)),
  _drawTriangles: drawTriangles,
  _playUserAudioBuffer: playUserAudioBuffer,
  _setupPass: (id: u32): void => (id ? setupBlendPass() : setupOpaquePass()),
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

  let accum = 0;
  let prev = performance.now();
  const onFrame = (ts: DOMHighResTimeStamp) => {
    accum += ts > prev ? ts - prev : 0;
    prev = ts;
    const A = 1000 / 60;
    if ((accum / A) | 0) {
      const w = gl.drawingBufferWidth;
      const h = gl.drawingBufferHeight;
      beginFrame(w, h);
      zig._onFrameRequest((accum / A) | 0, w, h);
      if (import.meta.env.DEV) {
        updateStatsText(ts);
      }
      accum -= ((accum / A) | 0) * A;
    }
    requestAnimationFrame(onFrame);
  };
  requestAnimationFrame(onFrame);
};
