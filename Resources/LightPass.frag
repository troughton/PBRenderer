#version 410

#include "CameraSpacePosition.glsl"

out vec4 outputColour;
in vec2 uv;
in vec3 cameraDirection;

uniform sampler2D gBuffer0;
uniform sampler2D gBufferDepth;

uniform vec2 depthRange;
uniform vec3 matrixTerms;

void main() {
    vec3 cameraSpacePosition = CalculateCameraSpacePositionFromWindow(texture(gBufferDepth, uv).r, cameraDirection, depthRange, matrixTerms);
    
    vec3 normal = texture(gBuffer0, uv).xyz;
    
    outputColour = vec4(normal, 1);
}