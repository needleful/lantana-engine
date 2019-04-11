// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module graphics.buffer;

import graphics.gl;

import core.types;

alias VboId = GLuint;

// Lower level construct for rendering,
// part of a model.
struct VertexBuffer
{
	VboId id;
	Vec3[] vertices;

	this(Vec3[] verts)
	{
		vertices = verts;

		glGenBuffers(1, &id);

		glBindBuffer(GL_ARRAY_BUFFER, id);

		glBufferData(GL_ARRAY_BUFFER, bytesize, vertices.ptr, GL_STATIC_DRAW);

		assert(glGetError() == GL_NO_ERROR);
	}

	@property ulong bytesize()
	{
		return vertices.length*Vec3.sizeof;
	}
}