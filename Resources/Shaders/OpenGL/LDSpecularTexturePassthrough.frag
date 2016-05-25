#version 410

#include "Sampling.glsl"

uniform samplerCube image;

in vec2 uv;
layout(location = 0) out vec4 out0;
layout(location = 1) out vec4 out1;
layout(location = 2) out vec4 out2;
layout(location = 3) out vec4 out3;
layout(location = 4) out vec4 out4;
layout(location = 5) out vec4 out5;

void main() {
    vec3 direction0 = cubeMapFaceUVToDirection(uv, 0);
    out0 = textureLod(image, direction0, 0);
    
    vec3 direction1 = cubeMapFaceUVToDirection(uv, 1);
    out1 = textureLod(image, direction1, 0);
    
    vec3 direction2 = cubeMapFaceUVToDirection(uv, 2);
    out2 = textureLod(image, direction2, 0);
    
    vec3 direction3 = cubeMapFaceUVToDirection(uv, 3);
    out3 = textureLod(image, direction3, 0);
    
    vec3 direction4 = cubeMapFaceUVToDirection(uv, 4);
    out4 = textureLod(image, direction4, 0);
    
    vec3 direction5 = cubeMapFaceUVToDirection(uv, 5);
    out5 = textureLod(image, direction5, 0);
}
