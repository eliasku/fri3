import { MEM } from "./base/mem";
import { GL, gl } from "./base/webgl";

export interface Texture {
  _texture?: WebGLTexture;
  _x: number;
  _y: number;

  // legacy
  _w: number;
  _h: number;
  _u0: number;
  _v0: number;
  _u1: number;
  _v1: number;
}

export interface Sprite {
  _texture?: WebGLTexture;
  _w: number;
  _h: number;
  // uv rect (stpq)
  _u0: number;
  _v0: number;
  _u1: number;
  _v1: number;
}

export const getSprite = (
  src: Texture,
  x: number,
  y: number,
  w: number,
  h: number,
  ax = 0.5,
  ay = 0.5,
): Texture => ({
  _texture: src._texture,
  _w: w,
  _h: h,
  _x: ax,
  _y: ay,
  _u0: x / src._w,
  _v0: y / src._h,
  _u1: w / src._w,
  _v1: h / src._h,
});

export const createTexture = (
  sizeOrWidth: number,
  height?: number,
): Texture => ({
  _texture: gl.createTexture()!,
  _w: sizeOrWidth,
  _h: height ?? sizeOrWidth,
  _x: 0,
  _y: 0,
  _u0: 0,
  _v0: 0,
  _u1: 1,
  _v1: 1,
});

export const uploadTexture = (
  texture: Texture,
  source?: TexImageSource,
  filter: GLint = GL.NEAREST,
): void => {
  gl.bindTexture(GL.TEXTURE_2D, texture._texture!);
  gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, filter);
  gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, filter);
  if (source) {
    gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE, source);
  } else {
    gl.texImage2D(
      GL.TEXTURE_2D,
      0,
      GL.RGBA,
      texture._w,
      texture._h,
      0,
      GL.RGBA,
      GL.UNSIGNED_BYTE,
      null,
    );
  }
};

const createColorTexture = (size: number, colorStyle: string) => {
  const texture = createTexture(size);
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext("2d");
  ctx.fillStyle = colorStyle;
  ctx.fillRect(0, 0, size, size);
  uploadTexture(texture, canvas);
  return texture;
};

export const textures = [createColorTexture(4, "#fff")];

// lib parts
export const __setTexture = (id: u32): void => {
  gl.activeTexture(GL.TEXTURE0);
  gl.bindTexture(GL.TEXTURE_2D, textures[id]._texture);
};

export const __setTextureData = (desc_ptr: Ptr<u8>): void => {
  const u32s = new Uint32Array(MEM.buffer);
  const id = u32s[desc_ptr >> 2];
  const width = u32s[(desc_ptr >> 2) + 1];
  const height = u32s[(desc_ptr >> 2) + 2];
  const filter = u32s[(desc_ptr >> 2) + 3];
  const wrap_s = u32s[(desc_ptr >> 2) + 4];
  const wrap_t = u32s[(desc_ptr >> 2) + 5];
  const data_ptr = u32s[(desc_ptr >> 2) + 6];
  const data_len = u32s[(desc_ptr >> 2) + 7];

  if (!textures[id]) {
    textures[id] = createTexture(width, height);
  }
  const texture = textures[id];
  texture._w = width;
  texture._h = height;
  gl.bindTexture(GL.TEXTURE_2D, texture._texture);
  gl.texParameteri(
    GL.TEXTURE_2D,
    GL.TEXTURE_WRAP_S,
    wrap_s ? GL.REPEAT : GL.CLAMP_TO_EDGE,
  );
  gl.texParameteri(
    GL.TEXTURE_2D,
    GL.TEXTURE_WRAP_T,
    wrap_t ? GL.REPEAT : GL.CLAMP_TO_EDGE,
  );
  gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST + filter);
  gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST + filter);
  const pixels = new Uint8Array(MEM.buffer, data_ptr, data_len);
  gl.texImage2D(
    GL.TEXTURE_2D,
    0,
    GL.RGBA,
    width,
    height,
    0,
    GL.RGBA,
    GL.UNSIGNED_BYTE,
    pixels,
  );
  if (import.meta.env.DEV) {
    // TODO: debug GL option
    const err = gl.getError();
    if (err) {
      console.error("gl error:", err);
    }
  }
};
