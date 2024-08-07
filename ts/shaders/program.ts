import { GL, gl } from "../lib/base/webgl";

export interface Program {
  _instance: WebGLProgram;
  _uMVP: WebGLUniformLocation;
  _uResolution: WebGLUniformLocation | null;
  _uImage0: WebGLUniformLocation | null;
  _aPosition: GLint;
  _aTexCoord: GLint;
  _aColorMul: GLint;
  _aColorAdd: GLint;
}

const compileShader = (
  source: string,
  shader: GLenum | WebGLShader,
): WebGLShader => {
  shader = gl.createShader(shader as GLenum)!;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);

  if (import.meta.env.DEV) {
    if (!gl.getShaderParameter(shader, GL.COMPILE_STATUS)) {
      const error = gl.getShaderInfoLog(shader);
      gl.deleteShader(shader);
      console.error(error);
    }
  }
  return shader;
};

export const bindAttrib = (
  name: GLint,
  size: number,
  stride: number,
  offset: number,
  type: GLenum,
  norm: boolean,
) => {
  gl.enableVertexAttribArray(name);
  gl.vertexAttribPointer(name, size, type, norm, stride, offset);
};

const createProgram = (vs: string, fs: string): WebGLProgram => {
  const vertShader = compileShader(vs, GL.VERTEX_SHADER);
  const fragShader = compileShader(fs, GL.FRAGMENT_SHADER);
  const program = gl.createProgram()!;
  gl.attachShader(program, vertShader);
  gl.attachShader(program, fragShader);
  gl.linkProgram(program);

  if (import.meta.env.DEV) {
    if (!gl.getProgramParameter(program, GL.LINK_STATUS)) {
      const error = gl.getProgramInfoLog(program);
      gl.deleteProgram(program);
      console.error(error);
    }
  }

  gl.deleteShader(vertShader);
  gl.deleteShader(fragShader);

  return program;
};

export const SHADER_A_POSITION = "aPosition";
export const SHADER_A_TEX_COORD = "aTexCoord";
export const SHADER_A_COLOR_MUL = "aColorMul";
export const SHADER_A_COLOR_ADD = "aColorAdd";
export const SHADER_U_RESOLUTION = "uResolution";
export const SHADER_U_IMAGE_0 = "uImage0";
export const SHADER_U_MVP = "uMVP";

export const createProgramObject = (vs: string, fs: string): Program => {
  const p = createProgram(vs, fs);
  return {
    _instance: p,
    _uMVP: gl.getUniformLocation(p, SHADER_U_MVP)!,
    _uResolution: gl.getUniformLocation(p, SHADER_U_RESOLUTION),
    _uImage0: gl.getUniformLocation(p, SHADER_U_IMAGE_0),
    _aPosition: gl.getAttribLocation(p, SHADER_A_POSITION),
    _aTexCoord: gl.getAttribLocation(p, SHADER_A_TEX_COORD),
    _aColorMul: gl.getAttribLocation(p, SHADER_A_COLOR_MUL),
    _aColorAdd: gl.getAttribLocation(p, SHADER_A_COLOR_ADD),
  };
};
