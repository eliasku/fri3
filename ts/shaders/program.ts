import { GL, gl } from "../lib/base/webgl";

export interface Program {
  _instance: WebGLProgram;
  _uMVP: WebGLUniformLocation;
  _aPosition: GLint;
  _aColorMul: GLint;
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

export const SHADER_A_POSITION = "x";
export const SHADER_A_COLOR_MUL = "y";
export const SHADER_U_MVP = "m";

export const createProgramObject = (vs: string, fs: string, p = createProgram(vs, fs)): Program => ({
  _instance: p,
  _uMVP: gl.getUniformLocation(p, SHADER_U_MVP)!,
  _aPosition: gl.getAttribLocation(p, SHADER_A_POSITION),
  _aColorMul: gl.getAttribLocation(p, SHADER_A_COLOR_MUL),
});
