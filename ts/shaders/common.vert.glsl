attribute vec3 x;
attribute vec2 y;
attribute vec4 z;
attribute vec4 w;

uniform mat4 m;

varying vec2 a;
varying vec4 b;
varying vec4 c;

void main() {
    a = y;
    b = z;
    c = w;
    gl_Position = m * vec4(x, 1.0);
}