precision mediump float;

uniform vec2 uResolution;
uniform sampler2D uImage0;

varying vec2 vTexCoord;
varying vec4 vColorMul;
varying vec4 vColorAdd;

#include common

void main() {
    vec4 color = vColorMul * texture2D(uImage0, vTexCoord) + vColorAdd;
    //if (gl_FragCoord.x / uResolution.x > 0.5) {
        color.xyz += dither_shift();
    //}
    gl_FragColor = color;
}