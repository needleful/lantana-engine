#version 130

// Size of the screen (or virtual canvas) in pixels
uniform uvec2 cam_resolution;
// camera position (pixels)
uniform ivec2 cam_position;

in ivec2 position;
in vec2 uv;

out vec2 vert_uv;

void main()
{
	ivec2 pos = position - cam_position;
	vec2 pos_norm = pos*2.0/cam_resolution;
	vert_uv = uv;
	gl_Position = vec4(pos_norm - vec2(1, 1), 0.0, 1.0);
}