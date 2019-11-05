#version 130

uniform vec3 light_color;
uniform vec3 light_direction;

in vec3 vert_normal;
out vec3 out_color;


void main()
{
	float light = clamp(light_direction.dot(vert_normal),0,1);

	out_color = light_color*light;
}