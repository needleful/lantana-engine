// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh;

import lanlib.math.vector;
import lanlib.math.transform;
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
struct MeshGroup
{
	Material material;
	UniformId transform;

	/**
	 *	Set the material being used by this mesh, loaded from shader files
	 */
	bool load_material(const string vert_file, const string frag_file)
	{
		GLuint matId = glCreateProgram();

		GLuint vert_shader = compile_shader(vert_file, GL_VERTEX_SHADER);
		GLuint frag_shader = compile_shader(frag_file, GL_FRAGMENT_SHADER);

		matId.glAttachShader(vert_shader);
		matId.glAttachShader(frag_shader);

		matId.glLinkProgram();

		GLint success;
		matId.glGetProgramiv(GL_LINK_STATUS, &success);

		if(!success)
		{
			debug
			{
				GLint loglen;
				matId.glGetProgramiv(GL_INFO_LOG_LENGTH, &loglen);

				char[] error;
				error.length = loglen;

				matId.glGetProgramInfoLog(cast(GLint)error.length, null, error.ptr);
				throw new Exception(format(
				"Failed to link program: %s || %s || %s", vert_file, frag_file, error));
			}
			else
			{
				return false;
			}
		}
		material = Material(matId);
		transform = material.get_param_id("transform");
		assert(transform != -1);

		assert(glGetError() == GL_NO_ERROR);
		return true;
	}

	void render(MeshInstance[] meshes)
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