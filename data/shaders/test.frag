#version 130

uniform sampler2D in_tex;

in vec2 vert_uv;
out vec3 out_color;

void main()
{
	vec3 c = texture(in_tex, vert_uv).rgb;
	if(c == vec3(1, 1, 0))
	{
		out_color = vec3(vert_uv, 0.1);
	}
	else 
	{
		out_color = c;
	}
}