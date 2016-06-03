uniform vec2 uv;

uniform sampler2D colourTexture;

#if CONVOLVE_HORIZONTAL
const ivec2 offsets[7] = {ivec2(-3, 0), ivec2(-2, 0), ivec2(-1, 0), ivec2(0, 0), ivec2(1, 0), ivec2(2, 0), ivec2(3, 0)};
#elif CONVOLVE_VERTICAL
const ivec2 offsets[7] = {ivec2(0, -3), ivec2(0, -2), ivec2(0, -1), ivec2(0, 0), ivec2(0, 1), ivec2(0, 2), ivec2(0, 3)};
#endif
const float weights[7] = {0.001f, 0.028f, 0.233f, 0.474f, 0.233f, 0.028f, 0.001f};

out vec4 blurredColour;

void main() {
    
    ivec2 fetchCoord = ivec2(gl_FragCoord.xy);
    
    vec4 color = float4(0.0f, 0.0f, 0.0f, 1.0f);
    
    for(uint i = 0u; i < 7u; ++i) {
        color += texelFetch(colourTexture, fetchCoord, offsets[i]) * weights[i];
    }
    blurredColour = vec4(color.rgb, 1.0f);
}
