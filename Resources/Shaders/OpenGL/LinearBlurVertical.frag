//http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/

#version 330 core

uniform sampler2D image;

in vec2 uv;
out vec4 FragmentColor;

uniform float offset[3] = float[]( 0.0, 1.3846153846, 3.2307692308 );
uniform float weight[3] = float[]( 0.2270270270, 0.3162162162, 0.0702702703 );

void main(void)
{
    FragmentColor = texture(image, uv) * weight[0];
    vec2 scale = uv / gl_FragCoord.xy;
    for (int i=1; i<3; i++) {
        FragmentColor += texture( image, ( uv + vec2(0.0, offset[i])*scale )) * weight[i];
        FragmentColor += texture( image, ( uv - vec2(0.0, offset[i])*scale )) * weight[i];
    }
}