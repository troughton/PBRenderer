#version 410

out vec4 outputColor;
in vec3 vertexNormal;

void main() {
    outputColor = vec4((vertexNormal + 1) * 0.5, 1.0);
}