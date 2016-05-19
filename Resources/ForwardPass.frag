#version 410

#include "Encoding.glsl"
#include "MaterialData.glsl"
#include "BRDF.glsl"

layout(location = 0) out vec4 outColour;

uniform sampler2D dfgTexture;

in vec2 uv;
in vec3 vertexNormal;
in vec4 cameraSpacePosition;

layout(std140) uniform Material {
    MaterialData material;
};

void main() {
    
    vec3 N = normalize(vertexNormal);
    
    float lightIntensity = 10.f;
    vec3 L = vec3(0, 0, 1);
    
    vec3 V = normalize(-cameraSpacePosition.xyz);
    float NdotV = abs(dot(N, V)) + 1e-5f; //bias the result to avoid artifacts
    float NdotL = saturate(dot(N, L));
    
    vec3 albedo;
    vec3 f0;
    float f90;
    float linearRoughness;
    
    evaluateMaterialData(material, albedo, f0, f90, linearRoughness);
    
    vec3 brdf = BRDF(V, L, N, NdotV, NdotL, albedo, f0, f90, linearRoughness);
    
    vec3 envMapColour = texture(dfgTexture, uv).rgb;
    
    outColour = vec4(pow(envMapColour, vec3(1 / 2.2)), 1);//vec4(brdf * NdotL * lightIntensity, 1);
}