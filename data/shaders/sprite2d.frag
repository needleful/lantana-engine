#version 130

uniform sampler2D sprite;
uniform vec3 color;

in vec2 tex_uv;

out vec4 out_color;

void main()
{
	out_color = texture(sprite, tex_uv)*vec4(color, 1.0);
}