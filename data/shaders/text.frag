#version 400

uniform vec4 color;
uniform sampler2D alpha;

in vec2 frag_uv;

out vec4 out_color;

void main()
{
	float a = texture(alpha, frag_uv).r;
	out_color = color * vec4(frag_uv,0.2,a);
}