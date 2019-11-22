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

struct Instance(MeshType)
{
	Transform transform;
	MeshType* mesh;
}

struct StaticMeshSystem
{
	struct Uniforms
	{
		// Vertex uniforms
		UniformId transform, projection;
		// Fragment uniforms
		UniformId light_color, light_direction, light_ambient;
	}
	struct Attributes
	{
		AttribId position, normal;
	}

	Attributes atr;
	StaticMesh[] meshes;
	Material mat;
	Uniforms un;

	this(uint reserved_meshes)
	{
		mat = load_material("data/shaders/worldspace3d.vert", "data/shaders/lighting3d.frag");

		atr.position = mat.get_attrib_id("position");
		atr.normal = mat.get_attrib_id("normal");

		un.transform = mat.get_uniform_id("transform");
		un.projection = mat.get_uniform_id("projection");
		un.light_color = mat.get_uniform_id("light_color");
		un.light_direction = mat.get_uniform_id("light_direction");
		un.light_ambient = mat.get_uniform_id("light_ambient");

		meshes.reserve(reserved_meshes);

		glcheck();
		assert(mat.can_render());
	}

	StaticMesh* build_mesh(GLBMeshAccessor accessor, ubyte[] data)
	{
		meshes.length += 1;
		meshes[$-1] = StaticMesh(this, accessor, data);
		return &meshes[$-1];
	}

	StaticMesh[] build_meshes(GLBLoadResults loaded)
	{
		uint start = meshes.length-1;
		meshes.length += loaded.accessors.length;
		uint end = meshes.length;
	}

	void render(Mat4 projection, Instance!StaticMesh[] instances)
	{
		glcheck();
		glEnable(GL_CULL_FACE);
		glDisable(GL_BLEND);

		mat.enable();
		mat.set_uniform(un.projection, projection);
		mat.set_uniform(un.light_color, Vec3(1,0.5,0.3));
		mat.set_uniform(un.light_direction, Vec3(-0.3, -1, 0.2));
		mat.set_uniform(un.light_ambient, Vec3(0, 0, 0.05));

		GLuint current_vao = 0;
		foreach(ref inst; instances)
		{
			inst.transform.compute_matrix();
			mat.set_uniform(un.transform, inst.transform.matrix);

			if(current_vao != inst.mesh.vao)
			{
				current_vao = inst.mesh.vao;
				glBindVertexArray(current_vao);
			}

			glDrawElements(
				GL_TRIANGLES, 
				cast(int)inst.mesh.accessor.indices.byteLength,
				inst.mesh.accessor.indices.componentType,
				cast(GLvoid*) inst.mesh.accessor.indices.byteOffset);
		}

		glBindVertexArray(0);
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
		glEnableVertexAttribArray(parent.atr.normal);

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, data.length, data.ptr, GL_STATIC_DRAW);
		
		glVertexAttribPointer(
			parent.atr.normal,
			accessor.normals.dataType.componentCount,
			accessor.normals.componentType,
			GL_FALSE,
			0,
			cast(void*) accessor.normals.byteOffset);

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
		glDisableVertexAttribArray(parent.atr.normal);

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