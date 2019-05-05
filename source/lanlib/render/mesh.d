// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.render.mesh;

import ecs.core;

import lanlib.render.material;

import lanlib.types.vector;
import lanlib.types.transform;
import lanlib.sys.gl;

alias VboId = GLuint;
alias EboId = GLuint;

alias Tri = Vector!(uint, 3);

struct Mesh2D
{
	VboId pos;
	VboId uv;
	EboId ebo;

	Vec2[] vertices;
	Vec2[] UVs;
	Tri[] triangles;

	this(Vec2[] verts, Vec2[] UVs, Tri[] elements) @nogc
	{

		assert(verts.length == UVs.length);
		this.vertices = verts;
		this.triangles = elements;
		this.UVs = UVs;

		glGenBuffers(1, &pos);
		glBindBuffer(GL_ARRAY_BUFFER, pos);
		glBufferData(GL_ARRAY_BUFFER, vertsize, vertices.ptr, GL_STATIC_DRAW);

		glGenBuffers(1, &uv);
		glBindBuffer(GL_ARRAY_BUFFER, uv);
		glBufferData(GL_ARRAY_BUFFER, vertsize, UVs.ptr, GL_STATIC_DRAW);

		glGenBuffers(1, &ebo);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, trisize, triangles.ptr, GL_STATIC_DRAW);

		glcheck();
	}

	~this()
	{
		glDeleteBuffers(1, &pos);
		glDeleteBuffers(1, &uv);
		glDeleteBuffers(1, &ebo);
	}

	@property const ulong vertsize() @safe @nogc nothrow
	{
		return vertices.length*Vec2.sizeof;
	}

	@property const ulong trisize() @safe @nogc nothrow
	{
		return triangles.length*Tri.sizeof;
	}
}

class Render2D : System!Mesh2D
{
	Material material;
	this(Material mat)
	{
		material = mat;
	}

	override bool process(Mesh2D[] meshes)
	{
		return true;
	}

}