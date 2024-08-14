precision mediump float;
uniform sampler2D i;
varying vec2 a;
varying vec4 b;
varying vec4 c;
void main() {
    vec4 f = vec4(b.xyz * b.w, (1.0 - c.a) * b.w) * texture2D(i, a);
    f.xyz += c.xyz * f.w;
    gl_FragColor = f;
}
