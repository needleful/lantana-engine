#version 130

uniform vec3 light_direction;
uniform float light_bias;
uniform sampler2D light_palette;

uniform sampler2D tex_albedo;
uniform float gamma;

in vec3 vert_normal;
in vec2 vert_uv;
in float area_gradient;

out vec3 out_color;

void main()
{
	float light = dot(normalize(light_direction), normalize(vert_normal)) + light_bias;

	vec3 albedo = texture(tex_albedo, vec2(vert_uv.x, -vert_uv.y)).rgb;
	vec3 light_mult = texture(light_palette, vec2(light, area_gradient)).rgb;

	out_color = pow(albedo*light_mult, vec3(1.0/gamma));
}