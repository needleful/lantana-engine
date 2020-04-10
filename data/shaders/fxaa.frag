#version 130

uniform sampler2D in_tex;
uniform sampler2D in_depth;
uniform vec2 resolution;

in vec2 vert_uv;

out vec3 out_color;

// Some poor attempt at FXAA
// Implemented with reference to Timothy Lotte's original paper and code by mattdesl

#define FXAA_LUMA_THRESHOLD 0.1
#define FXAA_DEPTH_THRESHOLD 0.0
#define FXAA_SUBPIX_TRIM 0.0
#define FXAA_SUBPIX_TRIM_SCALE 2
#define FXAA_SUBPIX_CAP 0.75
#define FXAA_SAMPLES 5
#define FXAA_SPAN 2.0

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
	vec3 dc = texture(in_depth, vert_uv).rgb;

	out_color = center;
	if(range <= FXAA_LUMA_THRESHOLD || lc == lmax || depthEdge() == 0)
	{
		return;
	}

	vec2 edgeDir = vec2(
		abs(l3 - lc) + abs(l2 - lc),
		abs(l1 - lc) + abs(l4 - lc)
	);

	float dirStrength = clamp((abs(abs(edgeDir.x) - abs(edgeDir.y))), 0.125, 1);
	edgeDir = vec2(edgeDir.x > edgeDir.y, edgeDir.x < edgeDir.y);

	vec3 lineSample = vec3(0);

	float samples = 0;
	bool doneP = false;
	bool doneN = false;
	float factor = 1;
	for(float i = 0; i < FXAA_SAMPLES; i++)
	{
		factor = 1;
		vec2 dir = edgeDir*(0.5 + i)*dirStrength*FXAA_SPAN;
		if(!doneP)
		{
			vec3 sampleP = texture(in_tex, vert_uv + dir/resolution).rgb;
			lineSample += sampleP*factor;
			samples += factor;

			doneP = abs(luma(sampleP) - lc) < FXAA_LUMA_THRESHOLD;
		}
		if(!doneN)
		{
			vec3 sampleN = texture(in_tex, vert_uv - dir/resolution).rgb;
			lineSample += sampleN*factor;
			samples += factor;

			doneN = abs(luma(sampleN) - lc) < FXAA_LUMA_THRESHOLD;
		}

		if(doneN && doneP)
		{
			break;
		}
	}

	lineSample = (lineSample + center)/(samples + 1);

	float llocal = (l1 + l2 + l3 + l4)*0.25;
	float rangeL = abs(llocal - lc);
	float blendL = ((rangeL/range)-FXAA_SUBPIX_TRIM )*FXAA_SUBPIX_TRIM_SCALE;
	blendL = clamp(blendL, 0, FXAA_SUBPIX_CAP);

	vec3 localRGB = (sample1 + sample2 + sample3 + sample4 + center)/5;

	out_color = mix(lineSample, localRGB, blendL);
}