#version 130

uniform sampler2D in_tex;
uniform vec3 color;

in vec2 vert_uv;

out vec4 out_color;

void main()
{
	float alpha = texture(in_tex, vert_uv).r;
	out_color = vec4(color, alpha);
}