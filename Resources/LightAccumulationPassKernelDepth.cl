#pragma OPENCL EXTENSION cl_khr_gl_sharing : enable
#pragma OPENCL EXTENSION cl_khr_gl_depth_images : enable

#include "LightAccumulationPass.cl"

__kernel void lightAccumulationPass(__write_only image2d_t lightAccumulationBuffer, float2 invImageDimensions,
                                    float4 nearPlaneAndDepthMin, float4 depthMaxAndMatrixTerms,
                                    mat4 worldToCameraMatrix,
                                    __read_only image2d_t gBuffer0Tex, __read_only image2d_t gBuffer1Tex, __read_only image2d_t gBuffer2Tex, __read_only image2d_depth_t gBufferDepthTex,
                                    __global LightData *lights, int lightCount) {
    
    const sampler_t sampler = CLK_FILTER_NEAREST | CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE;
    
    int2 coord = (int2)(get_global_id(0), get_global_id(1));
    float2 uv = (float2)(coord.x, coord.y) * invImageDimensions;
    
    
    float4 gBuffer0 = read_imagef(gBuffer0Tex, sampler, coord);
    float4 gBuffer1 = read_imagef(gBuffer1Tex, sampler, coord);
    float4 gBuffer2 = read_imagef(gBuffer2Tex, sampler, coord);
    float gBufferDepth = read_imagef(gBufferDepthTex, sampler, coord);
    
    float3 cameraSpacePosition = calculateCameraSpacePositionFromWindowZ(gBufferDepth, uv, nearPlaneAndDepthMin.xyz, (float2)(nearPlaneAndDepthMin.w, depthMaxAndMatrixTerms.x), matrixTerms.yzw);
    MaterialData material = decodeMaterialFromGBuffers(gBuffer0, gBuffer1, gBuffer2);
    
    float3 albedo;
    float3 f0;
    float f90;
    float linearRoughness;
    evaluateMaterialData(material, &albedo, &f0, &f90, &linearRoughness);
    
    
    float3 N = fast_normalize(decode(gBuffer0.xy));
    float3 V = fast_normalize(-cameraSpacePosition);
    float NdotV = fabs(dot(N, V)) + 1e-5f; //bias the result to avoid artifacts
    
    float3 lightAccumulation = (float3)(0, 0, 0);
    
    for (int i = 0; i < lightCount; i++) {
        lightAccumulation += evaluateLighting(cameraSpacePosition, &worldToCameraMatrix, V, N, NdotV, albedo, f0, f90, linearRoughness, lights[i]);
    }
    
    write_imagef(lightAccumulationBuffer, coord, (float4)(lightAccumulation, 1));
}