// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module components.render.mesh;

import lanlib.math.vector;
import lanlib.sys.gl;

alias VboId = GLuint;
alias EboId = GLuint;

alias Tri = Vector!(uint, 3);

struct Mesh
{
	VboId vbo;
	EboId ebo;

	Vec3[] vertices;
	Tri[] triangles;

	this(Vec3[] verts, Tri[] elements) @nogc
	{
		this.vertices = verts;
		this.triangles = elements;

		glGenBuffers(1, &vbo);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, vertsize, vertices.ptr, GL_STATIC_DRAW);

		glGenBuffers(1, &ebo);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, trisize, triangles.ptr, GL_STATIC_DRAW);

		glcheck;
	}

	@property const ulong vertsize() @safe @nogc nothrow
	{
		return vertices.length*Vec3.sizeof;
	}

	@property const ulong trisize() @safe @nogc nothrow
	{
		return triangles.length*Tri.sizeof;
	}
}