#version 130

uniform sampler2D in_tex;
uniform vec3 color;

in vec2 vert_uv;

out vec4 out_color;

void main()
{
	out_color = texture(in_tex, vert_uv)*vec4(color, 1.0);
}