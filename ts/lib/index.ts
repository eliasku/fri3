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
import { createFont, drawText, getFontStatus } from "./font";

let { sin, cos, pow, atan2 } = Math;

export const importMap = createExportMap({
  _log: (ptr: Ptr<u8>, len: usize) => {
    console.log(decodeText(ptr, len));
  },
  _drawTriangles: drawTriangles,
  _playUserAudioBuffer: playUserAudioBuffer,
  _setTexture: __setTexture,
  _setTextureData: __setTextureData,
  _setupPass: (id: u32) => {
    id ? setupBlendPass() : setupOpaquePass();
  },
  _createFont: createFont,
  _getFontStatus: getFontStatus,
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

  const zig = importZigFunctions(instance.exports);
  const raf = requestAnimationFrame;

  const onFrame = (ts: DOMHighResTimeStamp) => {
    const w = gl.drawingBufferWidth;
    const h = gl.drawingBufferHeight;
    beginFrame(w, h);
    zig._onFrame(ts / 1e3, w, h);
    if (import.meta.env.DEV) {
      updateStatsText(ts);
    }
    raf(onFrame);
  };

  const onFirstFrame = (ts: DOMHighResTimeStamp) => {
    const w = gl.drawingBufferWidth;
    const h = gl.drawingBufferHeight;
    zig._onFirstFrame(ts / 1e3, w, h);
    raf(onFrame);
  };

  initMemoryObjects(zig._memory);
  setupInput(zig._onPointerEvent, zig._onKeyboardEvent);
  zig._onSetup();
  raf(onFirstFrame);
};
