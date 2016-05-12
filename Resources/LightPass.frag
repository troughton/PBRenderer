#version 410

out vec4 outputColor;
in vec2 uv;

uniform sampler2D gBufferSampler;

void main() {
    outputColor = texture(gBufferSampler, uv);
}