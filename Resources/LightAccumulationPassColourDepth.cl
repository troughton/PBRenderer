#pragma OPENCL EXTENSION cl_khr_gl_sharing : enable

#include "LightAccumulationPass.cl"

__kernel void lightAccumulationPassKernel(__write_only image2d_t lightAccumulationBuffer, float2 invImageDimensions,
                                    float4 nearPlaneAndProjectionTerms,
                                    __read_only image2d_t gBuffer0Tex, __read_only image2d_t gBuffer1Tex, __read_only image2d_t gBuffer2Tex, __read_only image2d_t gBufferDepthTex,
                                    __global LightData *lights, int lightCount) {
    
    const sampler_t sampler = CLK_FILTER_NEAREST | CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE;
    
    int2 coord = (int2)(get_global_id(0), get_global_id(1));
    float2 uv = (float2)(coord.x, coord.y) * invImageDimensions;
    
    float4 gBuffer0 = read_imagef(gBuffer0Tex, sampler, coord);
    float4 gBuffer1 = read_imagef(gBuffer1Tex, sampler, coord);
    float4 gBuffer2 = read_imagef(gBuffer2Tex, sampler, coord);
    float gBufferDepth = read_imagef(gBufferDepthTex, sampler, coord).r;

    lightAccumulationPass(lightAccumulationBuffer, invImageDimensions, nearPlaneAndProjectionTerms, gBuffer0, gBuffer1, gBuffer2, gBufferDepth, lights, lightCount, coord, uv);
}