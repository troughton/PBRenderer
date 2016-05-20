//const sampler_t smp = CLK_FILTER_NEAREST;
__kernel void imagefill(const float4 val, __write_only image2d_t output)
{
	int2 coord = (int2)(get_global_id(0), get_global_id(1));
	write_imagef(output, coord, val);
}