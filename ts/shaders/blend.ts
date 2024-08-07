import frag from "./blend.frag.glsl";
import vert from "./common.vert.glsl";
import { createProgramObject } from "./program";

export const blendProgram = createProgramObject(vert, frag);
