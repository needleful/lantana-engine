#version 130

uniform float color_boost;
uniform sampler2D tex_albedo;
uniform float gamma;

in vec3 vert_color;
in vec2 vert_uv;

out vec4 out_color;

void main()
{
	float alpha = texture(tex_albedo, vec2(vert_uv.x, -vert_uv.y)).r;

	out_color = vec4(pow(vert_color, vec3(1.0/gamma)), alpha);
}