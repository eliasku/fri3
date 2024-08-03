import frag from './opaque.frag.glsl';
import vert from './opaque.vert.glsl';
import { createProgramObject } from './program';

export const opaqueProgram = createProgramObject(vert, frag);
