// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh;

import lanlib.math.matrix;
import lanlib.math.vector;
import lanlib.math.transform;

import lanlib.sys.gl;
import lanlib.sys.memory:GpuResource;
import lanlib.types;

struct VboId
{
	mixin StrictAlias!GLuint;
}
struct EboId
{
	mixin StrictAlias!GLuint;
}
struct VaoId
{
	mixin StrictAlias!GLuint;
}

alias Tri = Vector!(uint, 3);

@GpuResource
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

		glGenBuffers(1, vbo.ptr);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, vertsize, vertices.ptr, GL_STATIC_DRAW);

		glGenBuffers(1, ebo.ptr);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, trisize, triangles.ptr, GL_STATIC_DRAW);

		glcheck;
	}

	~this()
	{
		glDeleteBuffers(1, vbo.ptr);
		glDeleteBuffers(1, ebo.ptr);
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

struct MeshInstance
{
	Mesh* mesh;
	Transform transform;

	this(Mesh* mesh, Transform transform) @nogc @safe nothrow
	{
		this.mesh = mesh;
		this.transform = transform;
	}
}

import std.format;
import std.stdio;

import render.material;

/**
 *  A System for meshes rendered with the same material.
 */
struct MeshGroup
{
	Material* material;
	UniformId transform;
	MeshInstance[] meshes;

	this(Material* mat, MeshInstance[] meshes) @nogc
	{
		transform = mat.get_param_id("transform");
		assert(transform != -1, "material has no transform property");
		material = mat;
		this.meshes = meshes;
	}

	void render() @nogc
	{
		material.enable();
		glEnableVertexAttribArray(0);
		glcheck();
		
		foreach(ref MeshInstance instance; meshes)
		{
			material.set_param(transform, instance.transform.matrix);
			Mesh* mesh = instance.mesh;

			glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
			glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, cast(const GLvoid*) 0);
			
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);
			glDrawElements(GL_TRIANGLES, cast(int)mesh.triangles.length*3, GL_UNSIGNED_INT, cast(const GLvoid*)0);
			
			glcheck();
		}
		glDisableVertexAttribArray(0);
	}
}

/**
	A system for multiple instances of the same mesh
 */
struct MultiMesh
{
	Mesh *mesh;
	Material *material;
	Transform[] transforms;
	UniformId transform;

	this(Mesh* mesh, Material* mat, Transform[] transforms) @nogc
	{
		transform = mat.get_param_id("transform");
		assert(transform != -1, "material has no transform property");
		material = mat;
		this.mesh = mesh;
		this.transforms = transforms;
	}

	void update_transform(uint id, ref Transform transform)
	{
		transforms[id] = transform;
	}

	void render() @nogc
	{
		material.enable();
		debug
		{
			if(transform < 0)
			{
				throw new Exception("Could not find transform uniform for this material.  A transform is required for MeshGroup.");
			}
		}
		glcheck();
		glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
		glEnableVertexAttribArray(0);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, cast(const GLvoid*) 0);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);

		int vert_count = cast(int)mesh.triangles.length*3;
		foreach(ref Transform t; transforms)
		{
			material.set_param(transform, t.matrix);
			glDrawElements(GL_TRIANGLES, vert_count, GL_UNSIGNED_INT, cast(const GLvoid*)0);
		}
		glDisableVertexAttribArray(0);
		glcheck();
	}
}

struct Mesh2D
{
	VboId pos;
	VboId uv;
	EboId ebo;
	VaoId vao;

	iVec2[] vertices;
	Vec2[] UVs;
	Tri[] triangles;

	this(iVec2[] verts, Vec2[] UVs, Tri[] elements) @nogc
	{

		assert(verts.length == UVs.length);
		this.vertices = verts;
		this.triangles = elements;
		this.UVs = UVs;

		glGenBuffers(1, pos.ptr);
		glBindBuffer(GL_ARRAY_BUFFER, pos);
		glBufferData(GL_ARRAY_BUFFER, vertsize, vertices.ptr, GL_STATIC_DRAW);

		glGenBuffers(1, uv.ptr);
		glBindBuffer(GL_ARRAY_BUFFER, uv);
		glBufferData(GL_ARRAY_BUFFER, vertsize, UVs.ptr, GL_STATIC_DRAW);

		glGenBuffers(1, ebo.ptr);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, trisize, triangles.ptr, GL_STATIC_DRAW);

		glcheck();
	}

	~this()
	{
		glDeleteBuffers(1, pos.ptr);
		glDeleteBuffers(1, uv.ptr);
		glDeleteBuffers(1, ebo.ptr);
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

struct Render2D
{
	Material material;
	this(Material mat)
	{
		material = mat;
	}

	bool process(Mesh2D[] meshes)
	{
		return true;
	}

}