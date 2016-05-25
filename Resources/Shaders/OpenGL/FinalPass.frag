#version 410

uniform sampler2D lightAccumulationBuffer;

in vec2 uv;

out vec4 finalColour;

void main() {
    finalColour = texture(lightAccumulationBuffer, uv);
}