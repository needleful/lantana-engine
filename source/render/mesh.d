// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh;

debug import std.stdio;
debug import std.format;

import lanlib.math.matrix;
import lanlib.math.vector;
import lanlib.math.transform;

import lanlib.formats.gltf2;
import lanlib.sys.gl;
import lanlib.sys.memory:GpuResource;
import lanlib.types;

import render.material;

struct VBO
{
	GLuint[2] data;
	const GLuint elements()
	{
		return data[0];
	}

	const GLuint vertices()
	{
		return data[1];
	}

	GLuint* ptr()
	{
		return data.ptr;
	}

	const uint count()
	{
		return cast(uint) data.length;
	}
}

// 3D meshes
struct MeshSystem
{
	struct Uniforms
	{
		// Vertex uniforms
		UniformId transform, projection;
		// Fragment uniforms
		UniformId color;
	}
	struct Attributes
	{
		AttribId position;
	}

	Attributes atr;
	Mesh[] meshes;
	Material mat;
	Uniforms un;

	this(uint reserved_meshes)
	{
		mat = load_material("data/shaders/worldspace3d.vert", "data/shaders/flat_color.frag");

		atr.position = mat.get_attrib_id("position");

		un.transform = mat.get_uniform_id("transform");
		un.projection = mat.get_uniform_id("projection");
		un.color = mat.get_uniform_id("color");

		meshes.reserve(reserved_meshes);

		glcheck();
	}

	Mesh* build_mesh(Vec3[] vertices, ushort[] elements)
	{
		meshes.length += 1;
		meshes[$-1] = Mesh(this, vertices, elements);
		return &meshes[$-1];
	}

	void render(Mat4 projection, Instance!Mesh[] instances)
	{
		glcheck();

		glEnable(GL_CULL_FACE);
		glDisable(GL_BLEND);
		mat.enable();
		mat.set_uniform(un.projection, projection);

		glEnableVertexAttribArray(atr.position);

		foreach(ref inst; instances)
		{
			inst.transform.compute_matrix();
			mat.set_uniform(un.transform, inst.transform.matrix);
			mat.set_uniform(un.color, inst.color);

			glBindVertexArray(inst.mesh.vao);
			glDrawElements(GL_TRIANGLES, cast(int)inst.mesh.elements.length, GL_UNSIGNED_SHORT, cast(GLvoid*) 0);
		}

		glBindVertexArray(0);

		glDisableVertexAttribArray(atr.position);
	}
}

struct Instance(MeshType)
{
	Transform transform;
	MeshType* mesh;
	Vec3 color;
}

struct Mesh
{
	Vec3[] vertices;
	ushort[] elements;
	VBO vbo;
	GLuint vao;

	this(MeshSystem parent, Vec3[] vertices, ushort[] elements)
	{
		glcheck();

		this.vertices = vertices;
		this.elements = elements;

		glGenBuffers(vbo.count(), vbo.ptr());
		glGenVertexArrays(1, &vao);

		glBindVertexArray(vao);
		glEnableVertexAttribArray(parent.atr.position);

		glBindBuffer(GL_ARRAY_BUFFER, vbo.vertices());
		glBufferData(GL_ARRAY_BUFFER, vertices.length*Vec3.sizeof, vertices.ptr, GL_STATIC_DRAW);
		glVertexAttribPointer(parent.atr.position, 3, GL_FLOAT, GL_FALSE, 0, cast(void*) 0);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo.elements());
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, elements.length*ushort.sizeof, elements.ptr, GL_STATIC_DRAW);

		glBindVertexArray(0);
		glDisableVertexAttribArray(parent.atr.position);

		glcheck();
	}

	~this()
	{
		glDeleteBuffers(vbo.count(), vbo.ptr());
		glDeleteVertexArrays(1, &vao);
		glcheck();
		debug printf("Deleting mesh (vao %u)\n", vao);
	}
}


struct StaticMeshSystem
{
	struct Uniforms
	{
		// Vertex uniforms
		UniformId transform, projection;
		// Fragment uniforms
		UniformId color;
	}
	struct Attributes
	{
		AttribId position;
	}

	Attributes atr;
	StaticMesh[] meshes;
	Material mat;
	Uniforms un;

	this(uint reserved_meshes)
	{
		mat = load_material("data/shaders/worldspace3d.vert", "data/shaders/flat_color.frag");

		atr.position = mat.get_attrib_id("position");

		un.transform = mat.get_uniform_id("transform");
		un.projection = mat.get_uniform_id("projection");
		un.color = mat.get_uniform_id("color");

		meshes.reserve(reserved_meshes);

		glcheck();
	}

	StaticMesh* build_mesh(GLBMeshAccessor accessor, ubyte[] data)
	{
		meshes.length += 1;
		meshes[$-1] = StaticMesh(this, accessor, data);
		return &meshes[$-1];
	}

	void render(Mat4 projection, Instance!StaticMesh[] instances)
	{
		glcheck();
		glEnable(GL_CULL_FACE);
		glDisable(GL_BLEND);

		mat.enable();
		mat.set_uniform(un.projection, projection);

		glEnableVertexAttribArray(atr.position);

		foreach(ref inst; instances)
		{
			inst.transform.compute_matrix();
			mat.set_uniform(un.transform, inst.transform.matrix);
			mat.set_uniform(un.color, inst.color);

			glBindVertexArray(inst.mesh.vao);
			glDrawElements(
				GL_TRIANGLES, 
				cast(int)inst.mesh.accessor.indices.byteLength,
				inst.mesh.accessor.indices.componentType,
				cast(GLvoid*) inst.mesh.accessor.indices.byteOffset);
		}

		glBindVertexArray(0);

		glDisableVertexAttribArray(atr.position);
	}
}

struct StaticMesh
{
	ubyte[] data;
	GLBMeshAccessor accessor;
	GLuint vbo, vao;

	this(ref StaticMeshSystem parent, GLBMeshAccessor accessor, ubyte[] data)
	{
		this.data = data;
		this.accessor = accessor;

		glcheck();
		glGenBuffers(1, &vbo);
		glGenVertexArrays(1, &vao);

		glBindVertexArray(vao);

		glEnableVertexAttribArray(parent.atr.position);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, data.length, data.ptr, GL_STATIC_DRAW);

		glVertexAttribPointer(
			parent.atr.position,
			accessor.positions.dataType.componentCount,
			accessor.positions.componentType,
			GL_FALSE,
			0,
			cast(void*) accessor.positions.byteOffset);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo);

		glBindVertexArray(0);
		glDisableVertexAttribArray(parent.atr.position);

		glcheck();
	}

	~this()
	{
		debug printf("Deleting StaticMesh (vao %d)\n", vao);
		glDeleteBuffers(1, &vbo);
		glDeleteVertexArrays(1, &vao);
		glcheck();
	}
}