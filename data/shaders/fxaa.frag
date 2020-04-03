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
#define FXAA_SPAN 8.0
#define FXAA_SAMPLES 4

float luma(vec3 color)
{
	return color.r*0.3 + color.g*0.5 + color.b*0.2;
}

float depthEdge()
{
	float dc = texture(in_depth, vert_uv).r;
	float d1 = texture(in_depth, vert_uv + vec2(1)/resolution).r;
	float d2 = texture(in_depth, vert_uv + vec2(-1)/resolution).r;
	// float d3 = texture(in_depth, vert_uv + vec2(1, 0)/resolution).r;
	// float d4 = texture(in_depth, vert_uv + vec2(-1,0)/resolution).r;

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
	}

	vec3 sample5 = texture(in_tex, vert_uv + vec2(1)/resolution).rgb;
	vec3 sample6 = texture(in_tex, vert_uv + vec2(-1)/resolution).rgb;
	vec3 sample7 = texture(in_tex, vert_uv + vec2(1, -1)/resolution).rgb;
	vec3 sample8 = texture(in_tex, vert_uv + vec2(-1, 1)/resolution).rgb;

	float l5 = luma(sample5);
	float l6 = luma(sample6);
	float l7 = luma(sample7);
	float l8 = luma(sample8);

	vec2 edgeDir = vec2(
		abs((l5 + l7) - (l6 + l8)),
		abs((l5 + l8) - (l6 + l7))
	);
	edgeDir = min(vec2(FXAA_SPAN), edgeDir);

	// float reduce = max((l5 + l6 + l7 + l8)*0.25*0.12, 0.12);
	// float inverseDir = (1.0/min(edgeDir.x, edgeDir.y)) + reduce;

	// edgeDir = min(vec2(FXAA_SPAN), edgeDir*inverseDir);

	// edgeDir.xy = edgeDir.yx;

	// out_color = vec3(normalize(edgeDir), 0);
	// return;

	vec3 lineSample = center;

	bool posDone = false;
	bool negDone = false;
	for(int i = 0; i < FXAA_SAMPLES; i++)
	{
		if(!posDone)
		{
			vec3 sampleP = texture(in_tex, vert_uv + edgeDir*(0.5 + i)/resolution).rgb;
			float lumaP = luma(sampleP);
			posDone = abs(lumaP - lc) >= FXAA_LUMA_THRESHOLD;
			if(!posDone)
			{
				lineSample -= center/(FXAA_SAMPLES*2);
				lineSample += sampleP/(FXAA_SAMPLES*2);
			}
		}
		if(!negDone)
		{
			vec3 sampleN = texture(in_tex, vert_uv - edgeDir*(0.5 + i)/resolution).rgb;
			float lumaN = luma(sampleN);
			negDone = abs(lumaN - lc) >= FXAA_LUMA_THRESHOLD;
			if(!negDone)
			{
				lineSample -= center/(FXAA_SAMPLES*2);
				lineSample += sampleN/(FXAA_SAMPLES*2);
			}
		}
		if(posDone && negDone)
		{
			out_color = vec3(1);
			break;
		}
	}

	out_color = (
			lineSample*(FXAA_SAMPLES*2-1)
			+ (sample1 + sample2 + sample3 + sample4 + sample5 + sample6 + sample7 + sample8)/8
			)/(FXAA_SAMPLES*2);
}