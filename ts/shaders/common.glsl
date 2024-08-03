
vec3 dither_shift() {
    float dither_bit = 6.0;
    float grid_position = fract( dot( gl_FragCoord.xy , vec2(1.0/16.0,10.0/36.0) + 0.093 ) );
    float dither_shift = (0.25) * (1.0 / (pow(2.0,dither_bit) - 1.0));
    vec3 dither_shift_RGB = vec3(dither_shift, dither_shift, dither_shift);
    dither_shift_RGB = mix(2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position);
    return vec3(0.5 / 255.0) + dither_shift_RGB; 
}
