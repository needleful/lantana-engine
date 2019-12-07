#version 130

uniform vec3 light_color;
uniform vec3 light_direction;
uniform vec3 light_ambient;
uniform float light_bias;

in vec3 vert_normal;
in vec3 debug_color;
out vec3 out_color;


void main()
{
	float light = clamp( dot(normalize(light_direction), vert_normal) + light_bias , 0.0, 1.0);

	out_color = debug_color * (light_color*light + light_ambient);
}