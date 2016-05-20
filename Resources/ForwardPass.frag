#version 410

#include "Encoding.glsl"
#include "MaterialData.glsl"
#include "BRDF.glsl"
#include "Light.glsl"
#include "Camera.glsl"

layout(location = 0) out vec4 outColour;

uniform sampler2D dfgTexture;
uniform int lightCount;
uniform mat4 worldToCameraMatrix;

in vec2 uv;
in vec3 vertexNormal;
in vec4 cameraSpacePosition;

layout(std140) uniform Material {
    MaterialData material;
};

const uint MaxLights = 32;

layout(std140) uniform Light {
    LightData lights[MaxLights];
};

void main() {
    
    vec3 N = normalize(vertexNormal);
    
    vec3 V = normalize(-cameraSpacePosition.xyz);
    float NdotV = abs(dot(N, V)) + 1e-5f; //bias the result to avoid artifacts

    
    vec3 albedo;
    vec3 f0;
    float f90;
    float linearRoughness;
    
    evaluateMaterialData(material, albedo, f0, f90, linearRoughness);
    
    vec3 lightAccumulation = vec3(0);
    
    for (int lightIndex = 0; lightIndex < lightCount; lightIndex++) {
        
        LightData light = lights[lightIndex];
        
        float lightIntensity = light.colourAndIntensity.a * 10;
        vec3 lightColour = light.colourAndIntensity.rgb;
        
        vec3 L = normalize((worldToCameraMatrix * (light.lightToWorld * vec4(0, 0, 1, 0))).xyz);
        float NdotL = saturate(dot(N, L));
        
        vec3 brdf = BRDF(V, L, N, NdotV, NdotL, albedo, f0, f90, linearRoughness);
        
        lightAccumulation += brdf * NdotL * lightIntensity * lightColour;
    }
    
    
    vec3 epilogue = epilogueLighting(lightAccumulation, 1.0);
    
    outColour = vec4(accurateLinearToSRGB(epilogue), 1);
}