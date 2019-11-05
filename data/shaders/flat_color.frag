#version 130

uniform vec3 light_color;

in vec3 vert_normal;
out vec3 out_color;


void main()
{
	out_color = vert_normal+light_color;
}