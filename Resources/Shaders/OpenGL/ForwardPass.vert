#version 410
layout(location = 0) in vec4 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec2 textureCoordinate;

uniform mat4 mvp;
uniform mat3 normalModelToCameraMatrix;
uniform mat4 modelToCameraMatrix;

out vec4 cameraSpacePosition;
out vec3 vertexNormal;
out vec2 uv;

void main() {
    vertexNormal = normalize(normalModelToCameraMatrix * normal);
    cameraSpacePosition = modelToCameraMatrix * position;
    uv = textureCoordinate;
    gl_Position = mvp * position;
}