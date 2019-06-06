#version 130

uniform vec3 color;

in vec4 vert_color;
out vec3 out_color;


void main()
{
	out_color = vert_color.rgb+color;
}