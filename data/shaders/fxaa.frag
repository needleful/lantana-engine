#version 130

uniform sampler2D in_tex;
uniform sampler2D in_depth;
uniform vec2 resolution;

in vec2 vert_uv;

out vec3 out_color;

// FXAA implemented with heavy reference to Timothy Lotte's original paper

#define FXAA_LUMA_THRESHOLD 0.25
#define FXAA_DEPTH_THRESHOLD 0.00000001
#define FXAA_EDGE_SIZE 0.5
#define FXAA_EDGE_WEIGHT 1

float luma(vec3 color)
{
	return color.g * 1.9 + color.r;
}

vec2 edgeDetect()
{
	float lc = luma(texture(in_tex, vert_uv).rgb);
	float l1 = luma(texture(in_tex, vert_uv + vec2(0, 1)*FXAA_EDGE_SIZE/resolution).rgb);
	float l2 = luma(texture(in_tex, vert_uv + vec2(0,-1)*FXAA_EDGE_SIZE/resolution).rgb);
	float l3 = luma(texture(in_tex, vert_uv + vec2(1, 0)*FXAA_EDGE_SIZE/resolution).rgb);
	float l4 = luma(texture(in_tex, vert_uv + vec2(-1,0)*FXAA_EDGE_SIZE/resolution).rgb);

	return vec2(abs(l1 - lc) + abs(l2 - lc), abs(l3 - lc) + abs(l4 - lc));
}

float depthEdge()
{
	float dc = texture(in_depth, vert_uv).r;
	float d1 = texture(in_depth, vert_uv + vec2(0, 1)*FXAA_EDGE_SIZE/resolution).r;
	float d2 = texture(in_depth, vert_uv + vec2(0,-1)*FXAA_EDGE_SIZE/resolution).r;
	float d3 = texture(in_depth, vert_uv + vec2(1, 0)*FXAA_EDGE_SIZE/resolution).r;
	float d4 = texture(in_depth, vert_uv + vec2(-1,0)*FXAA_EDGE_SIZE/resolution).r;

	return (abs(d1 - dc) + abs(d2 - dc) + abs(d3 - dc) + abs(d4 - dc))*(1-dc);
}

void main()
{
	vec3 center = texture(in_tex, vert_uv).rgb;
	vec2 edge = edgeDetect();

	if(edge.x < FXAA_LUMA_THRESHOLD && edge.y < FXAA_LUMA_THRESHOLD)
	{
		out_color = center;
		return;
	}
	else if(depthEdge() < FXAA_DEPTH_THRESHOLD)
	{
		// out_color = vec3(1);
		out_color = center;
		return;
	}
	else
	{
		edge = normalize(edge)*FXAA_EDGE_WEIGHT;
		// out_color = vec3(edge, 0);
		// return;
	}
	vec3 sample1 = texture(in_tex, vert_uv + vec2(edge.y, edge.x)/resolution).rgb;
	vec3 sample2 = texture(in_tex, vert_uv + vec2(edge.y, -edge.x)/resolution).rgb;
	vec3 sample3 = texture(in_tex, vert_uv + vec2(-edge.y, edge.x)/resolution).rgb;
	vec3 sample4 = texture(in_tex, vert_uv + vec2(-edge.y, -edge.x)/resolution).rgb;

	vec3 sample5, sample6;

	if(edge.x > edge.y)
	{
		sample5 = texture(in_tex, vert_uv + vec2(edge.y, edge.x/2)/resolution).rgb;
		sample6 = texture(in_tex, vert_uv + vec2(edge.y, -edge.x/2)/resolution).rgb;
	}
	else
	{
		sample5 = texture(in_tex, vert_uv + vec2(edge.y/2, edge.x)/resolution).rgb;
		sample6 = texture(in_tex, vert_uv + vec2(-edge.y/2, edge.x)/resolution).rgb;
	}

	out_color = (center + sample1 + sample2 + sample3 + sample4 + sample5 + sample6) / 7;
}