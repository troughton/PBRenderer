//http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/

#version 330 core

uniform sampler2D image;
uniform float dimension;

out vec4 FragmentColor;

uniform float offset[3] = float[]( 0.0, 1.3846153846, 3.2307692308 );
uniform float weight[3] = float[]( 0.2270270270, 0.3162162162, 0.0702702703 );

void main(void)
{
	FragmentColor = texture( image, vec2(gl_FragCoord)/dimension ) * weight[0];
	for (int i=1; i<3; i++) {
		FragmentColor += texture( image, ( vec2(gl_FragCoord)+vec2(0.0, offset[i]) )/dimension ) * weight[i];
		FragmentColor += texture( image, ( vec2(gl_FragCoord)-vec2(0.0, offset[i]) )/dimension ) * weight[i];
	}
}
