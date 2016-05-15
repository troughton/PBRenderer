#version 410

#include "CameraSpacePosition.glsl"
#include "Encoding.glsl"

out vec4 outputColour;
in vec2 uv;
in vec3 cameraDirection;

uniform sampler2D gBuffer0Texture;
uniform sampler2D gBuffer1Texture;
uniform sampler2D gBuffer2Texture;
uniform sampler2D gBuffer3Texture;
uniform sampler2D gBufferDepthTexture;

uniform vec2 depthRange;
uniform vec3 matrixTerms;

void main() {
    
    float gBufferDepth = texture(gBufferDepthTexture, uv).r;
    vec4 gBuffer0 = texture(gBuffer0Texture, uv);
    vec4 gBuffer1 = texture(gBuffer1Texture, uv);
    vec4 gBuffer2 = texture(gBuffer2Texture, uv);
    vec4 gBuffer3 = texture(gBuffer3Texture, uv);
    
    vec3 normal = normalize(decode(gBuffer0.xy));
    
    MaterialData data = decodeMaterialFromGBuffers(gBuffer0, gBuffer1, gBuffer2);
    
    vec3 cameraSpacePosition = CalculateCameraSpacePositionFromWindow(gBufferDepth, cameraDirection, depthRange, matrixTerms);
    
    outputColour = vec4(max(dot(normal, vec3(0, 0, 1)), 0) * data.baseColour, 1);
}