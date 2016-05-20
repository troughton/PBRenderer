#include "BRDF.cl"

typedef struct MaterialData {
    float3 baseColour;
    float smoothness;
    float metalMask;
    float reflectance;
} MaterialData;

float3 decode(float2 enc) {
    float2 fenc = enc*4-2;
    float f = dot(fenc,fenc);
    float g = sqrt(1-f/4);
    float3 n;
    n.xy = fenc*g;
    n.z = 1-f/2;
    return n;
}

MaterialData decodeMaterialFromGBuffers(float4 gBuffer0, float4 gBuffer1, float4 gBuffer2) {
    MaterialData data;
    data.smoothness = gBuffer0.b;
    data.baseColour = gBuffer1.rgb;
    data.metalMask = gBuffer2.g;
    data.reflectance = gBuffer2.b;
    
    return data;
}

__kernel void lightAccumulationPass(__write_only image2d_t lightAccumulationBuffer, __read_only image2d_t gBuffer0, __read_only image2d_t gBuffer1, __read_only image2d_t gBufferDepth) {

    const sampler_t sampler = CLK_FILTER_NEAREST | CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE;
    
    int2 coord = (int2)(get_global_id(0), get_global_id(1));
    
    float4 baseColour = read_imagef(gBuffer1, sampler, coord);
    baseColour.w = 1;
    
    write_imagef(lightAccumulationBuffer, coord, baseColour);
}