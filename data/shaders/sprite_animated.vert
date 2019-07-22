#version 400

// Translation in pixels
uniform ivec2 translation;
// Size of the screen (or virtual canvas) in pixels
uniform uvec2 screen_size;
// The size of the sprite's frame in pixels
uniform ivec2 frame_size;
// the horizontal scale of the frame relative to the spritesheet
uniform float frame_scale;
// offset in UV-space of the frame within the sprite
uniform vec2 frame_offset;

layout(location = 0) in ivec2 vert_position;
layout(location = 1) in vec2 vert_uv;

out vec2 frag_uv;

void main()
{
	ivec2 pos = (vert_position*frame_size) + translation;
	vec2 pos_norm = pos*2.0/screen_size;
	// TODO: non-linear sprite sheets
	frag_uv = vert_uv*vec2(frame_scale, 1) + frame_offset;
	gl_Position = vec4(pos_norm - vec2(1, 1), 0.0, 1.0);
}