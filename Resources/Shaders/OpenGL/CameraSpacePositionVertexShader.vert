#version 410
layout(location = 0) in vec4 position;

out vec3 cameraDirection;
out vec2 uv;

uniform vec2 nearPlane;


#define MaxShadowMaps 1
uniform mat4 worldToLightClipMatrices[MaxShadowMaps];
out vec4 lightSpacePosition;

void main() {
    uv = (position.xy + 1)/2;
    cameraDirection = vec3(nearPlane * position.xy, -1);
    lightSpacePosition = worldToLightClipMatrices[0] * position;
    gl_Position = position;
}

