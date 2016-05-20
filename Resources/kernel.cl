//const sampler_t smp = CLK_FILTER_NEAREST;
__kernel void imageColourChange(__write_only image2d_t image)
{
    
    int2 coord = (int2)(get_global_id(0), get_global_id(1));
    float4 colour = (float4)(coord.x / 512.f, coord.y / 512.f, 0, 1);
	write_imagef(image, coord, colour);
}