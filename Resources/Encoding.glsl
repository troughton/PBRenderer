vec2 encode (vec3 n) {
    float f = sqrt(8*n.z+8);
    return n.xy / f + 0.5;
}

vec3 decode(vec2 enc) {
    vec2 fenc = enc*4-2;
    float f = dot(fenc,fenc);
    float g = sqrt(1-f/4);
    vec3 n;
    n.xy = fenc*g;
    n.z = 1-f/2;
    return n;
}
