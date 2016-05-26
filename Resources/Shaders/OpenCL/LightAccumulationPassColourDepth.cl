#pragma OPENCL EXTENSION cl_khr_gl_sharing : enable

#include "LightAccumulationPass.cl"

__kernel void lightAccumulationPassKernel(__write_only image2d_t lightAccumulationBuffer, float2 invImageDimensions,
                                    float4 nearPlaneAndProjectionTerms,
                                    __read_only image2d_t gBuffer0Tex, __read_only image2d_t gBuffer1Tex, __read_only image2d_t gBuffer2Tex, __read_only image2d_t gBufferDepthTex,
                                    __global LightData *lights, int lightCount, float16 cameraToWorldMatrix) {
    
    const sampler_t sampler = CLK_FILTER_NEAREST | CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE;
    
    int2 coord = (int2)(get_global_id(0), get_global_id(1));
    float2 uv = (float2)(coord.x, coord.y) * invImageDimensions;

    uint gBuffer0 = read_imageui(gBuffer0Tex, sampler, coord).x;
    float4 gBuffer1 = read_imagef(gBuffer1Tex, sampler, coord);
    float4 gBuffer2 = read_imagef(gBuffer2Tex, sampler, coord);
    float gBufferDepth = read_imagef(gBufferDepthTex, sampler, coord).x;

    float3 result = lightAccumulationPass(nearPlaneAndProjectionTerms, gBuffer0, gBuffer1, gBuffer2, gBufferDepth, lights, lightCount, uv, cameraToWorldMatrix);
    
    write_imagef(lightAccumulationBuffer, coord, (float4)(result, 1));
}