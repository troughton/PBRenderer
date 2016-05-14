#version 410
layout(location = 0) in vec4 position;
layout(location = 1) in vec3 normal;

uniform mat4 mvp;
uniform mat3 normalModelToCameraMatrix;
out vec3 vertexNormal;

void main() {
    vertexNormal = normalize(normalModelToCameraMatrix * normal);
    gl_Position = mvp * position;
}