import frag from "./main.frag.glsl";
import vert from "./main.vert.glsl";
import { createProgramObject } from "./program";

export const mainProgram = createProgramObject(vert, frag);
