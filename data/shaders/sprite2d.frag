#version 130

uniform sampler2D in_tex;

in vec2 vert_uv;

out vec4 out_color;

void main()
{
	out_color = texture(in_tex, vert_uv) + vec4(0.3, 0.6, 0.1, 1);
}