#version 400

uniform sampler2D sprite;

in vec2 frag_uv;
out vec3 out_color;

void main()
{
	vec3 color = texture(sprite, frag_uv).rgb;
	if(color == vec3(1, 1, 0))
	{
		discard;
	}
	out_color = color;
}