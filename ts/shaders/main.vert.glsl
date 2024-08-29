attribute vec3 x;
attribute vec4 y;

uniform mat4 m;

varying vec4 c;

void main() {
    c = y;
    gl_Position = m * vec4(x, 1.0);
}