#version 130

uniform vec3 light_direction;
uniform float light_bias;
uniform sampler2D light_palette;

in vec3 vert_normal;
in float area_gradient;

out vec3 out_color;

void main()
{
	float light = dot(normalize(light_direction), normalize(vert_normal)) + light_bias;
	out_color = texture(light_palette, vec2(light, area_gradient)).xyz;
}