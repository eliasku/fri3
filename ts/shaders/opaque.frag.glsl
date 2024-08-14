precision mediump float;
uniform sampler2D i;
varying vec2 a;
varying vec4 b;
varying vec4 c;
void main() {
    gl_FragColor = b * texture2D(i, a) + c;
}
