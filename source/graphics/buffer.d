// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module graphics.buffer;

import graphics.gl;

import core.types;

alias VboId = GLuint;

struct VertexBuffer
{
	VboId id;
	Vec3[] vertices;

	ulong bytesize()
	{
		return vertices.length*Vec3.sizeof;
	}
}