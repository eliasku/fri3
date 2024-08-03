attribute vec3 aPosition;
attribute vec2 aTexCoord;
attribute vec4 aColorMul;
attribute vec4 aColorAdd;

uniform mat4 uMVP;

varying vec2 vTexCoord;
varying vec4 vColorMul;
varying vec4 vColorAdd;

void main() {
    vTexCoord = aTexCoord;
    vColorMul = aColorMul;
    vColorAdd = aColorAdd;
    gl_Position = uMVP * vec4(aPosition, 1.0);
}