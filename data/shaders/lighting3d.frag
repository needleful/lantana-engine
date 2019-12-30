#version 130

uniform vec3 light_color;
uniform vec3 light_direction;
uniform vec3 light_ambient;
uniform float light_bias;

in vec3 vert_normal;
out vec3 out_color;

void main()
{
	float light = dot(normalize(light_direction), normalize(vert_normal)) + light_bias;
	light = clamp(light, 0, 1);
	out_color = light_color*light + light_ambient;
}