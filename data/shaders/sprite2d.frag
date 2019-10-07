#version 130

uniform sampler2D in_tex;

in vec2 vert_uv;

out vec4 out_color;

void main()
{
	out_color = texture(in_tex, vert_uv);
	//out_color = vec4(1, 1, 0.2, 1);
}