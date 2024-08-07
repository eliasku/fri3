precision mediump float;

uniform vec2 uResolution;
uniform sampler2D uImage0;

varying vec2 vTexCoord;
varying vec4 vColorMul;
varying vec4 vColorAdd;

void main() {
    gl_FragColor = vColorMul * texture2D(uImage0, vTexCoord) + vColorAdd;
}
