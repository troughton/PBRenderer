//http://aras-p.info/texts/CompactNormalStorage.html
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

#include "MaterialData.glsl"

void encodeMaterialToGBuffers(in MaterialData data, inout vec4 gBuffer0, inout vec4 gBuffer1, inout vec4 gBuffer2) {
    gBuffer0.b = data.smoothness;
    gBuffer1.rgb = data.baseColour;
    gBuffer2.g = data.metalMask;
    gBuffer2.b = data.reflectance;
}

MaterialData decodeMaterialFromGBuffers(vec4 gBuffer0, vec4 gBuffer1, vec4 gBuffer2) {
    MaterialData data;
    data.smoothness = gBuffer0.b;
    data.baseColour = gBuffer1.rgb;
    data.metalMask = gBuffer2.g;
    data.reflectance = gBuffer2.b;
    
    return data;
}