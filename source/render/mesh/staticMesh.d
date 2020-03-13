// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh.staticMesh;

import std.algorithm: endsWith;
debug import std.stdio;
debug import std.format;

import gl3n.interpolate;
import gl3n.linalg;

import lanlib.math.transform;
import lanlib.file.gltf2;
import lanlib.file.lgbt;
import render.gl;
import lanlib.util.memory;
import lanlib.types;

import render.lights;
import render.material;
import render.mesh.attributes;
import render.textures;


struct StaticMeshSystem
{
	struct Uniforms
	{
		// Vertex uniforms
		UniformId transform, projection;
		// Texture uniforms
		UniformId tex_albedo;
		// Light Uniforms
		LightUniforms light;
	}

	struct Attributes
	{
		float position;
		float normal;
		float uv;
	}

	struct Loader
	{
		enum position = "POSITION";
		enum normal = "NORMAL";
		enum uv = "TEXCOORD_0";
	}

	alias Spec = MeshSpec!(Attributes, Loader);

	Spec.attribType atr;
	OwnedList!StaticMesh meshes;
	Material mat;
	Uniforms un;

	this(Material p_material) 
	{
		mat = p_material;

		atr = Spec.attribType(mat);
		un.transform = mat.getUniformId("transform");
		un.projection = mat.getUniformId("projection");
		un.tex_albedo = mat.getUniformId("tex_albedo");

		un.light = LightUniforms(mat);

		glcheck();
		assert(mat.canRender());
	}

	StaticMesh* loadMesh(string p_filename, ref Region p_alloc)
	{
		GLBStaticLoadResults loaded;
		if(p_filename.endsWith(".glb"))
		{
			loaded = glbLoad(p_filename, p_alloc);
		}
		else
		{
			loaded = binaryLoad!GLBStaticLoadResults(p_filename, p_alloc);
		}
		meshes.place(this, loaded.accessor, loaded.data, loaded.bufferSize, p_alloc);
		return &meshes[$-1];
	}
	
	void render(mat4 p_projection, ref LightInfo p_lights, StaticMeshInstance[] p_instances)
	{
		glcheck();
		glEnable(GL_CULL_FACE);
		glDisable(GL_BLEND);
		glEnable(GL_DEPTH_TEST);

		mat.enable();
		mat.setUniform(un.projection, p_projection);
		mat.setUniform(un.light.palette, 0);
		mat.setUniform(un.tex_albedo, 1);

		un.light.set(mat, p_lights);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, p_lights.palette.id);

		GLuint current_vao = 0;
		foreach(ref inst; p_instances)
		{
			inst.transform.computeMatrix();
			mat.setUniform(un.transform, inst.transform.matrix);

			if(current_vao != inst.mesh.vao)
			{
				current_vao = inst.mesh.vao;
				glBindVertexArray(current_vao);

				glActiveTexture(GL_TEXTURE1);
				glBindTexture(GL_TEXTURE_2D, inst.mesh.tex_albedo.id);
			}

			glDrawElements(
				GL_TRIANGLES, 
				cast(int)inst.mesh.accessor.indices.byteLength,
				inst.mesh.accessor.indices.componentType,
				cast(GLvoid*) inst.mesh.accessor.indices.byteOffset);
		}

		glBindVertexArray(0);
	}

	void clearMeshes() @nogc
	{
		foreach(i; 0..meshes.length)
		{
			meshes[i].clear();
		}
		meshes.clearNoGC();
	}
}

struct StaticMesh
{
	ubyte[] data;
	GLBMeshAccessor accessor;
	Texture!Color tex_albedo;
	GLuint vbo, vao;

	this(ref StaticMeshSystem p_parent, ref GLBMeshAccessor p_accessor, ubyte[] p_data, uint p_bufferSize, ref Region p_alloc) 
	{
		data = p_data;
		accessor = p_accessor;

		glcheck();
		glGenBuffers(1, &vbo);
		glGenVertexArrays(1, &vao);

		glBindVertexArray(vao);

		p_parent.atr.enable();

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, p_bufferSize, data.ptr, GL_STATIC_DRAW);
		
		p_parent.atr.initialize(accessor);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo);

		glBindVertexArray(0);
		p_parent.atr.disable();

		with(p_accessor.tex_albedo)
		{
			tex_albedo = Texture!Color(true, type, p_data[byteOffset..byteOffset+byteLength], p_alloc);
		}

		glcheck();
	}

	this(ref StaticMesh rhs) @nogc nothrow
	{
		data = rhs.data;
		accessor = rhs.accessor;
		tex_albedo = rhs.tex_albedo;

		vbo = rhs.vbo;
		vao = rhs.vao;

		rhs.vao = 0;
		rhs.vbo = 0;
	}

	~this() @nogc
	{
		clear();
	}

	void clear() @nogc
	{
		//debug printf("Deleting StaticMesh (vao %d)\n", vao);
		glDeleteBuffers(1, &vbo);
		glDeleteVertexArrays(1, &vao);
		glcheck();
	}
}

struct StaticMeshInstance
{
	Transform transform;
	StaticMesh* mesh;
}