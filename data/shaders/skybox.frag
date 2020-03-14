#version 130

uniform float color_boost;
uniform sampler2D tex_albedo;

in vec3 vert_color;
in vec2 vert_uv;

out vec4 out_color;

void main()
{
	float alpha = texture(tex_albedo, vec2(vert_uv.x, -vert_uv.y)).r;

	out_color = vec4(vert_color*color_boost, alpha);
}