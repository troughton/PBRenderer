#version 410
layout(location = 0) in vec4 position;
layout(location = 1) in vec3 normal;

uniform mat4 modelToClipMatrix;
uniform mat4 modelToWorldMatrix;
uniform vec3 cameraPositionWorld;
uniform mat3 normalModelToWorldMatrix;

out vec4 worldSpacePosition;
out vec3 worldSpaceViewDirection;
out vec3 vertexNormal;

void main() {
    
    vec4 wsPosition = modelToWorldMatrix * position;
    worldSpacePosition = wsPosition;
    worldSpaceViewDirection = normalize(cameraPositionWorld - wsPosition.xyz);
    
    vertexNormal = normalize(normalModelToWorldMatrix * normal);
    gl_Position = modelToClipMatrix * position;
}