// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh;

debug import std.stdio;
debug import std.format;

import gl3n.linalg;

import lanlib.math.transform;
import lanlib.formats.gltf2;
import lanlib.sys.gl;
import lanlib.sys.memory:GpuResource;
import lanlib.types;

import render.Material;

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
		UniformId light_color, light_direction, light_ambient, light_bias;
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
		mat = load_Material("data/shaders/worldspace3d.vert", "data/shaders/lighting3d.frag");

		atr.position = mat.get_attrib_id("position");
		atr.normal = mat.get_attrib_id("normal");

		un.transform = mat.get_uniform_id("transform");
		un.projection = mat.get_uniform_id("projection");
		un.light_color = mat.get_uniform_id("light_color");
		un.light_direction = mat.get_uniform_id("light_direction");
		un.light_ambient = mat.get_uniform_id("light_ambient");
		un.light_bias = mat.get_uniform_id("light_bias");

		meshes.reserve(reserved_meshes);

		glcheck();
	}

	StaticMesh* build_mesh(GLBMeshAccessor accessor, ubyte[] data)
	{
		meshes.length += 1;
		meshes[$-1] = StaticMesh(this, accessor, data);
		return &meshes[$-1];
	}

	void render(mat4 projection, Instance!StaticMesh[] instances)
	{
		glcheck();
		glEnable(GL_CULL_FACE);
		glDisable(GL_BLEND);

		mat.enable();
		mat.set_uniform(un.projection, projection);
		mat.set_uniform(un.light_color, vec3(1,0.5,0.3));
		mat.set_uniform(un.light_direction, vec3(-0.3, -1, 0.2));
		mat.set_uniform(un.light_ambient, vec3(0, 0, 0.1));
		mat.set_uniform(un.light_bias, 0.2);

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

struct BoneIndex { mixin StrictAlias!ubyte; }
struct Bone
{
	mat4 transform; 
	/// indeces to parent in an armature
	BoneIndex parent;
}

struct Armature
{
	/// Cannot be more than 24 bones by shader limitation
	Bone[] skeleton;
}


struct Animation
{

}

struct AnimatedMeshSystem
{
	struct Uniforms
	{
		// Vertex uniforms
		UniformId transform, projection, bones;
		// Fragment uniforms
		UniformId light_color, light_direction, light_ambient, light_bias;
	}
	struct Attributes
	{
		AttribId position, normal, bone_weight, bone_idx;
	}

	Attributes atr;
	AnimatedMesh[] meshes;
	Material mat;
	Uniforms un;

	this(uint reserved_meshes)
	{
		mat = load_Material("data/shaders/animated3d.vert", "data/shaders/lighting3d.frag");

		atr.position = mat.get_attrib_id("position");
		atr.normal = mat.get_attrib_id("normal");
		atr.bone_weight = mat.get_attrib_id("bone_weight");
		atr.bone_idx = mat.get_attrib_id("bone_idx");

		un.transform = mat.get_uniform_id("transform");
		un.projection = mat.get_uniform_id("projection");
		un.light_color = mat.get_uniform_id("light_color");
		un.light_direction = mat.get_uniform_id("light_direction");
		un.light_ambient = mat.get_uniform_id("light_ambient");
		un.light_bias = mat.get_uniform_id("light_bias");
		un.bones = mat.get_uniform_id("bones");

		meshes.reserve(reserved_meshes);

		glcheck();
	}

	AnimatedMesh* build_mesh(GLBAnimatedAccessor accessor, ubyte[] data)
	{
		meshes.length += 1;
		meshes[$-1] = AnimatedMesh(this, accessor, data);
		return &meshes[$-1];
	}

	void render(mat4 projection, Instance!AnimatedMesh[] instances)
	{
		glcheck();
		glEnable(GL_CULL_FACE);
		glDisable(GL_BLEND);

		mat4x3[] mats;
		mats.length = 24;

		mat.enable();
		mat.set_uniform(un.projection, projection);
		mat.set_uniform(un.light_color, vec3(1,0.5,0.3));
		mat.set_uniform(un.light_direction, vec3(-0.3, -1, 0.2));
		mat.set_uniform(un.light_ambient, vec3(0, 0, 0.1));
		mat.set_uniform(un.light_bias, 0.2);
		mat.set_uniform(un.bones, mats);
		glcheck();

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
			glcheck();
		}

		glBindVertexArray(0);
	}
}


struct AnimatedMesh
{
	ubyte[] data;
	GLBAnimatedAccessor accessor;
	GLuint vbo, vao;

	this(ref AnimatedMeshSystem parent, GLBAnimatedAccessor accessor, ubyte[] data)
	{
		this.data = data;
		this.accessor = accessor;

		glcheck();
		glGenBuffers(1, &vbo);
		glGenVertexArrays(1, &vao);

		glBindVertexArray(vao);

		glEnableVertexAttribArray(parent.atr.position);
		glEnableVertexAttribArray(parent.atr.normal);
		glEnableVertexAttribArray(parent.atr.bone_weight);
		glEnableVertexAttribArray(parent.atr.bone_idx);

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

		glVertexAttribPointer(
			parent.atr.bone_idx,
			accessor.bone_idx.dataType.componentCount,
			accessor.bone_idx.componentType,
			GL_FALSE,
			0,
			cast(void*) accessor.bone_idx.byteOffset);

		glVertexAttribPointer(
			parent.atr.bone_weight,
			accessor.bone_weight.dataType.componentCount,
			accessor.bone_weight.componentType,
			GL_FALSE,
			0,
			cast(void*) accessor.bone_weight.byteOffset);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo);

		glBindVertexArray(0);
		glDisableVertexAttribArray(parent.atr.position);
		glDisableVertexAttribArray(parent.atr.normal);
		glDisableVertexAttribArray(parent.atr.bone_weight);
		glDisableVertexAttribArray(parent.atr.bone_idx);

		glcheck();
	}

	~this()
	{
		debug printf("Deleting AnimatedMesh (vao %d)\n", vao);
		glDeleteBuffers(1, &vbo);
		glDeleteVertexArrays(1, &vao);
		glcheck();
	}
}