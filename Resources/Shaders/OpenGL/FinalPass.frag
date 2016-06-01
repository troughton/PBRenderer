#version 410

uniform sampler2D lightAccumulationBuffer;

out vec4 finalColour;

float A = 0.15;
float B = 0.50;
float C = 0.10;
float D = 0.20;
float E = 0.02;
float F = 0.30;
float W = 11.2;

//http://gamedev.stackexchange.com/questions/62917/uncharted-2-tone-mapping-and-an-eye-adaptation
vec3 Uncharted2Tonemap(vec3 x) {
    vec3 numerator = x*(A*x+C*B)+ D*E;
    vec3 denominator = x*(A*x+B)+D*F;
    vec3 divided = numerator/denominator;
    return divided - E/F;
}

void main() {
    vec4 lightAccumulation = texelFetch(lightAccumulationBuffer, ivec2(gl_FragCoord.xy), 0);
    finalColour = vec4(Uncharted2Tonemap(lightAccumulation.xyz), lightAccumulation.w);
}