#version 130

uniform sampler2D in_tex;

in vec2 vert_uv;
in vec3 color;

out vec4 out_color;

void main()
{
	out_color = vec4(color, texture(in_tex, vert_uv).a);
}