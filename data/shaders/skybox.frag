#version 130

uniform float color_boost;
uniform sampler2D tex_albedo;
uniform float gamma;

in vec3 vert_color;
in vec2 vert_uv;

out vec4 out_color;

void main()
{
	vec3 texture = texture(tex_albedo, vec2(vert_uv.x, -vert_uv.y)).rgb;

	// When we have HDR:
	// vec3 color = vert_color*(1+texture.g*4 + texture.b*16);
	vec3 color = vert_color;
	out_color = vec4(pow(color, vec3(1.0/gamma)), texture.r);
}