#version 410

#include "Sampling.glsl"

uniform samplerCube image;
uniform float valueMultiplier;

in vec2 uv;
layout(location = 0) out vec4 out0;
layout(location = 1) out vec4 out1;
layout(location = 2) out vec4 out2;
layout(location = 3) out vec4 out3;
layout(location = 4) out vec4 out4;
layout(location = 5) out vec4 out5;

void main() {
    
    vec3 direction0, direction1, direction2, direction3, direction4, direction5;
    cubeMapFaceUVsToDirections(uv, direction0, direction1, direction2, direction3, direction4, direction5);
    
    out0 = valueMultiplier * textureLod(image, direction0, 0);
    
    out1 = valueMultiplier * textureLod(image, direction1, 0);
    
    out2 = valueMultiplier * textureLod(image, direction2, 0);
    
    out3 = valueMultiplier * textureLod(image, direction3, 0);
    
    out4 = valueMultiplier * textureLod(image, direction4, 0);
    
    out5 = valueMultiplier * textureLod(image, direction5, 0);
}
