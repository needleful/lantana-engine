#version 130

uniform vec3 light_color;
uniform vec3 light_direction;
uniform vec3 light_ambient;

in vec3 vert_normal;
out vec3 out_color;


void main()
{
	float light = clamp( dot(normalize(light_direction), vert_normal) , 0.0, 1.0);

	out_color = light_color*light + light_ambient;
}