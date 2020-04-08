#version 130

uniform sampler2D in_tex;
uniform sampler2D in_depth;
uniform vec2 resolution;

in vec2 vert_uv;

out vec3 out_color;

// FXAA implemented with heavy reference to Timothy Lotte's original paper
// Also with some reference to code by mattdesl

#define FXAA_LUMA_THRESHOLD 0.1
#define FXAA_DEPTH_THRESHOLD 0.0
#define FXAA_SUBPIX_TRIM 0.25
#define FXAA_SUBPIX_TRIM_SCALE 1
#define FXAA_SUBPIX_CAP 0.75
#define FXAA_SAMPLES 3

float luma(vec3 color)
{
	return color.r*0.3 + color.g*0.5 + color.b*0.2;
}

float depthEdge()
{
	float dc = texture(in_depth, vert_uv).r;
	float d1 = texture(in_depth, vert_uv + vec2(1)/resolution).r;
	float d2 = texture(in_depth, vert_uv + vec2(-1)/resolution).r;

	return (abs(d1 - dc) + abs(d2 - dc));
}

void main()
{ 
	vec3 center = texture(in_tex, vert_uv).rgb;

	vec3 sample1 = texture(in_tex, vert_uv + vec2(1, 0)/resolution).rgb;
	vec3 sample2 = texture(in_tex, vert_uv + vec2(0, -1)/resolution).rgb;
	vec3 sample3 = texture(in_tex, vert_uv + vec2(0, 1)/resolution).rgb;
	vec3 sample4 = texture(in_tex, vert_uv + vec2(-1, 0)/resolution).rgb;

	float lc = luma(center);
	float l1 = luma(sample1);
	float l2 = luma(sample2);
	float l3 = luma(sample3);
	float l4 = luma(sample4);

	float lmax = max(max(lc, max(l1, l2)), max(l3, l4));
	float lmin = min(min(lc, min(l1, l2)), min(l3, l4));

	float range = lmax - lmin;

	if(range <= FXAA_LUMA_THRESHOLD)
	{
		out_color = center;
		return;
	}
	else if(depthEdge() == 0)
	{
		out_color = center;
		return;
	}

	vec2 edgeDir = vec2(
		abs(l3 - lc) + abs(l2 - lc),
		abs(l1 - lc) + abs(l4 - lc)
	);

	edgeDir = vec2(edgeDir.x > edgeDir.y, edgeDir.x < edgeDir.y)*length(edgeDir);

	vec3 lineSample = vec3(0);

	float samples = 0;
	for(int i = 0; i < FXAA_SAMPLES; i++)
	{
		vec2 dir = edgeDir*(0.5 + i);
		float factor = pow(0.9, i);

		lineSample += texture(in_tex, vert_uv + dir/resolution).rgb*factor;
		lineSample += texture(in_tex, vert_uv - dir/resolution).rgb*factor;

		samples += 2*factor;
	}

	lineSample = (lineSample + center)/(samples + 1);

	float llocal = (l1 + l2 + l3 + l4)*0.25;
	float rangeL = abs(llocal - lc);
	float blendL = ((rangeL/range)-FXAA_SUBPIX_TRIM )*FXAA_SUBPIX_TRIM_SCALE;
	blendL = clamp(blendL, 0, FXAA_SUBPIX_CAP);

	vec3 localRGB = (sample1 + sample2 + sample3 + sample4 + center)/5;

	out_color = lineSample;
}