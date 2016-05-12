#version 410

out vec4 outputColor;
in vec2 uv;

uniform sampler2D positionSampler;
uniform sampler2D normalSampler;

void main() {
    
    vec3 normal = texture(positionSampler, uv).xyz;
    
    outputColor = vec4(normal, 1);
}