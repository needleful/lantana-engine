#version 130

in vec2 position;
in vec2 uv;

out vec2 vert_uv;

void main()
{
	vert_uv = uv;
	gl_Position = vec4(position, 0, 1.0);
}