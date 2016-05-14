#version 410

#include "CameraSpacePosition.glsl"
#include "Encoding.glsl"

out vec4 outputColour;
in vec2 uv;
in vec3 cameraDirection;

uniform sampler2D gBuffer0;
uniform sampler2D gBufferDepth;

uniform vec2 depthRange;
uniform vec3 matrixTerms;

void main() {
    vec3 cameraSpacePosition = CalculateCameraSpacePositionFromWindow(texture(gBufferDepth, uv).r, cameraDirection, depthRange, matrixTerms);
    
    vec3 normal = normalize(decode(texture(gBuffer0, uv).xy));
    
    outputColour = vec4(vec3(max(dot(normal, vec3(0, 0, 1)), 0)), 1);
}