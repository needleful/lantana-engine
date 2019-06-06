#version 130

//Constant for text pass
uniform ivec2 screen_size;
uniform ivec2 texture_size;

//Varies by textbox
uniform ivec2 translation;

in ivec2 position;
in ivec2 tex_pos;

out vec2 tex_uv;

void main()
{
	gl_Position = vec4((position + translation)/screen_size, 0.0, 1.0);
	tex_uv = tex_pos/texture_size;
}