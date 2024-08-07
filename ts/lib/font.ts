import { MEM, decodeText } from "./base/mem";

const canvas = document.createElement("canvas");
canvas.width = canvas.height = 128;
let ctx = canvas.getContext("2d")!;

export const drawText = (input_ptr: Ptr<void>, output_ptr: Ptr<void>): void => {
  const u32s = new Uint32Array(MEM.buffer);
  const textPtr = u32s[input_ptr >> 2];
  const textLen = u32s[(input_ptr >> 2) + 1];
  const text = decodeText(textPtr, textLen);
  const bufferPtr = u32s[(input_ptr >> 2) + 2];

  const outPixelsWidthIdx = output_ptr >> 2;
  const outPixelsHeightIdx = (output_ptr >> 2) + 1;

  ctx.font = `normal normal 16px Arial Black`;
  ctx.textBaseline = "alphabetic";
  ctx.textAlign = "left";
  ctx.fillStyle = "white";
  const {
    width: glyphAdvance,
    actualBoundingBoxAscent,
    actualBoundingBoxDescent,
    actualBoundingBoxLeft,
    actualBoundingBoxRight,
  } = ctx.measureText(text);

  // The integer/pixel part of the top alignment is encoded in metrics.glyphTop
  // The remainder is implicitly encoded in the rasterization
  const glyphTop = Math.ceil(actualBoundingBoxAscent);
  const glyphLeft = 0;

  // If the glyph overflows the canvas size, it will be clipped at the bottom/right
  const glyphWidth = Math.max(
    0,
    Math.ceil(actualBoundingBoxRight - actualBoundingBoxLeft),
  );
  const glyphHeight = Math.min(glyphTop + Math.ceil(actualBoundingBoxDescent));

  const padding = 1;
  // const width = glyphWidth + 2 * padding;
  // const height = glyphHeight + 2 * padding;

  ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
  ctx.fillText(text, padding, padding + glyphTop);

  const imageData = ctx.getImageData(padding, padding, glyphWidth, glyphHeight);
  const u8s = new Uint8Array(MEM.buffer);
  u8s.set(imageData.data, bufferPtr);

  u32s[outPixelsWidthIdx] = glyphWidth;
  u32s[outPixelsHeightIdx] = glyphHeight;
};
