// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh;

import ecs.core;

import lanlib.math.matrix;
import lanlib.math.vector;
import lanlib.math.transform;

import lanlib.sys.gl;
import lanlib.sys.memory:GpuResource;

alias VboId = GLuint;
alias EboId = GLuint;

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

		glGenBuffers(1, &vbo);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, vertsize, vertices.ptr, GL_STATIC_DRAW);

		glGenBuffers(1, &ebo);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, trisize, triangles.ptr, GL_STATIC_DRAW);

		glcheck;
	}

	~this()
	{
		glDeleteBuffers(1, &vbo);
		glDeleteBuffers(1, &ebo);
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

	this(Mesh* mesh, Transform transform)
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
class MeshGroup : System!MeshInstance
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

	override void process() @nogc
	{
		material.enable();
		debug
		{
			if(transform < 0)
			{
				throw new Exception("Could not find transform uniform for this material.  A transform is required for MeshGroup.");
			}
		}
		foreach(ref MeshInstance instance; meshes)
		{
			glcheck();
			material.set_param(transform, instance.transform.matrix);
			Mesh* mesh = instance.mesh;

			glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
			glEnableVertexAttribArray(0);

			glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, cast(const GLvoid*) 0);
			
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);
			glDrawElements(GL_TRIANGLES, cast(int)mesh.triangles.length*3, GL_UNSIGNED_INT, cast(const GLvoid*)0);

			glDisableVertexAttribArray(0);
			glcheck();
		}
	}
}

class MultiMesh : System!Transform
{
	Mesh *mesh;
	Material *material;
	Transform[] transforms;
	UniformId transform;

	this(Mesh* mesh, Material* mat, Transform[] transforms) @nogc
	{
		mat.set_attrib_id("position", 0);
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

	override void process() @nogc
	{
		material.enable();
		debug
		{
			if(transform < 0)
			{
				throw new Exception("Could not find transform uniform for this material.  A transform is required for MeshGroup.");
			}
		}
		uint rendered = 0;

		glcheck();
		glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo);
		glEnableVertexAttribArray(0);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, cast(const GLvoid*) 0);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);
		foreach(ref Transform t; transforms)
		{
			material.set_param(transform, t.matrix);
			glDrawElements(GL_TRIANGLES, cast(int)mesh.triangles.length*3, GL_UNSIGNED_INT, cast(const GLvoid*)0);
		}
		glDisableVertexAttribArray(0);
		glcheck();
	}
}