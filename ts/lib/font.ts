import { MEM, decodeText } from "./base/mem";

interface FontResource {
  _face: FontFace;
}

export const fonts: FontResource[] = [];

const loadFont = async (id: u32) => {
  const face = fonts[id]._face;
  let n = 3;
  while (n > 0) {
    try {
      await face.load();
      document.fonts.add(face);
      return;
    } catch {
      --n;
    }
  }
};

export const createFont = (input: Ptr<void>): u32 => {
  const u32s = new Uint32Array(MEM.buffer);
  const family = decodeText(u32s[input >> 2], u32s[(input >> 2) + 1]);
  const url = decodeText(u32s[(input >> 2) + 2], u32s[(input >> 2) + 3]);
  const id = fonts.length;
  const face = new FontFace(family, `url(${url})`);
  // const face = new FontFace(family, url);
  const font: FontResource = {
    _face: face,
  };
  fonts[id] = font;
  loadFont(id);
  return id;
};

export const getFontStatus = (id: u32): u32 => {
  return fonts[id]._face.status === "loaded" ? 1 : 0;
};

const canvas = document.createElement("canvas");
canvas.width = canvas.height = 128;
let ctx = canvas.getContext("2d", { willReadFrequently: !!canvas });

export const drawText = (input_ptr: Ptr<void>, output_ptr: Ptr<void>): void => {
  const u32s = new Uint32Array(MEM.buffer);
  const fontId = u32s[input_ptr >> 2];
  const textPtr = u32s[(input_ptr >> 2) + 1];
  const textLen = u32s[(input_ptr >> 2) + 2];
  const text = decodeText(textPtr, textLen);
  const bufferPtr = u32s[(input_ptr >> 2) + 3];

  const outPixelsWidthIdx = output_ptr >> 2;
  const outPixelsHeightIdx = (output_ptr >> 2) + 1;

  const face = fonts[fontId]._face;
  ctx.font = `${"normal"} ${"normal"} ${16}px ${face.family}`;
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
