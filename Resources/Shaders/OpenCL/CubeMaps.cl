
typedef enum CubeMapFace {
    CubeMapPositiveX = 0,
    CubeMapNegativeX,
    CubeMapPositiveY,
    CubeMapNegativeY,
    CubeMapPositiveZ,
    CubeMapNegativeZ
} CubeMapFace;

float4 textureCube(image2d_t *images, sampler_t sampler, float3 direction);
float4 textureCube(image2d_t *images, sampler_t sampler, float3 direction) {
        //    The largest component of the normal vector tells you which face it intersects. Next divide the normal vector by the absolute value of the largest component. Then scale and shift the other two components into the usual range for uvs ([0, 1] on each axis).
        float3 absDirection = fabs(direction);
        
        image2d_t image;
        float2 uv;
        
        if (absDirection.x >= absDirection.y && absDirection.x >= absDirection.z) {
            image = direction.x > 0 ? images[CubeMapPositiveX] : images[CubeMapNegativeX];
            
            uv = (float2)(direction.y, direction.z) * native_divide(0.5f, absDirection.x);
            
        } else if (absDirection.y >= absDirection.x && absDirection.y >= absDirection.z) {
            image = direction.y > 0 ? images[CubeMapPositiveY] : images[CubeMapNegativeY];
            
            uv = (float2)(direction.x, direction.z) * native_divide(0.5f, absDirection.y);
            
        } else {
            image = direction.z > 0 ? images[CubeMapPositiveZ] : images[CubeMapNegativeZ];
            
            uv = (float2)(direction.x, direction.y) * native_divide(0.5f, absDirection.z);
        }
        uv += (float2)(0.5f, 0.5f);
        
        return read_imagef(image, sampler, uv);

}