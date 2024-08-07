precision mediump float;

uniform sampler2D uImage0;
uniform vec2 uResolution;

varying vec2 vTexCoord;
varying vec4 vColorMul;
varying vec4 vColorAdd;

void main() {
    vec4 mult = vec4(vColorMul.xyz * vColorMul.w, (1.0 - vColorAdd.a) * vColorMul.w);
    vec4 color = mult * texture2D(uImage0, vTexCoord);
    color.xyz += vColorAdd.xyz * color.w;
    gl_FragColor = color;
}
