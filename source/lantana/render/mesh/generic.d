// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.render.mesh.generic;

import std.algorithm: endsWith;
import std.format;
debug import std.stdio;
import std.traits: FieldNameTuple;

import lantana.animation.skeletal;

import lantana.file.gltf2;
import lantana.file.lgbt;
import lantana.math;

import lantana.render.gl;
import lantana.render.lights;
import lantana.render.material;
import lantana.render.mesh.attributes;
import lantana.render.textures;

import lantana.types;

struct DefaultGlobalUniforms
{
	Mat4 projection;

	Vec3 light_direction;
	float light_bias;
	float area_span;
	float area_ceiling;
	float gamma;

	Texture!Color light_palette;
}

struct DefaultInstanceUniforms {
}

struct DefaultSettings
{
	enum alphaBlend = false;
	enum depthTest = true;
	enum depthWrite = true;
	enum filter = Filter(TexFilter.Linear, TexFilter.MipMaps);
	alias textureType = Color;
	alias globalUniforms = DefaultGlobalUniforms;
	alias instanceUniforms = DefaultInstanceUniforms;
}

template GenericMesh(Attrib, Loader, Settings = DefaultSettings)
{
	alias texture = Texture!(Settings.textureType);

	alias Spec = MeshSpec!(Attrib, Loader);
	private alias MeshData = GLBLoadResults!Spec.MeshData;

	alias GlobalUniforms = Settings.globalUniforms;
	static if (is(Settings.instanceUniforms == DefaultInstanceUniforms)) {
		struct InstanceUniforms
		{
			Transform transform;
			static if(Spec.isAnimated)
			{
				Mat4[] bones;
			}
			Texture!Color tex_albedo;
		}
	}
	else {
		alias InstanceUniforms = Settings.instanceUniforms;
	}

	alias Uniforms = UniformT!(GlobalUniforms, InstanceUniforms);

	struct System
	{
		Spec.attribType atr;
		Mesh[] meshes;
		GLuint[] vbos;
		texture[] textures;

		Material mat;
		Uniforms un;

		this(string p_vertShader, string p_fragShader) 
		{
			mat = loadMaterial(p_vertShader, p_fragShader);

			atr = Spec.attribType(mat);
			un = Uniforms(mat);

			glcheck();
			assert(mat.canRender());
		}

		~this()
		{
			clearMeshes();
		}

		Mesh*[string] loadMeshes(string p_filename, ref Region p_alloc)
		{
			glcheck();

			GLBLoadResults!Spec loaded;
			loaded = glbLoad!Spec(p_filename, p_alloc);

			GLBImage currentImage;
			Mesh*[string] result;
			foreach(name, meshData; loaded.meshes)
			{
				if(currentImage != meshData.accessor.tex_albedo)
				{
					currentImage = meshData.accessor.tex_albedo;
					with(meshData.accessor.tex_albedo)
					{
						textures ~= texture(type, loaded.data[byteOffset..byteOffset+byteLength], p_alloc, Settings.filter);
					}
				}

				uint offset, length;
				meshData.accessor.bounds(offset, length);
				meshData.accessor.subtractOffset(offset);
				debug writefln("Offset: %u, length: %u, of total %u", offset, length, loaded.data.length);

				GLuint vbo;
				glGenBuffers(1, &vbo);
				glBindBuffer(GL_ARRAY_BUFFER, vbo);
				glBufferData(GL_ARRAY_BUFFER, length, &loaded.data[offset], GL_STATIC_DRAW);
				vbos ~= vbo;

				meshes ~= Mesh(this, meshData, loaded.data, vbo);

				result[name] = &meshes[$-1];
			}
			glcheck();
			return result;
		}

		void render(ref Uniforms.global p_globals, Instance[] p_instances)
		{
			glcheck();
			glEnable(GL_CULL_FACE);

			static if(Settings.alphaBlend)
			{
				glEnable(GL_BLEND);
				glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
			}
			else
				glDisable(GL_BLEND);

			glcheck();

			static if(Settings.depthTest)
				glEnable(GL_DEPTH_TEST);
			else
				glDisable(GL_DEPTH_TEST);

			glcheck();

			static if(Settings.depthWrite)
				glDepthMask(GL_TRUE);
			else
				glDepthMask(GL_FALSE);

			mat.enable();
			
			glcheck();

			un.setUniforms(mat, p_globals);

			GLuint current_vao = 0;
			foreach(ref inst; p_instances)
			{
				glcheck();
				un.setUniforms(mat, inst.instanceData);

				if(current_vao != inst.mesh.vao)
				{
					current_vao = inst.mesh.vao;
					glBindVertexArray(current_vao);
				}
				glcheck();

				glDrawElements(
					GL_TRIANGLES, 
					cast(int)inst.mesh.accessor.indices.count(),
					inst.mesh.accessor.indices.componentType,
					cast(GLvoid*) inst.mesh.accessor.indices.byteOffset);
				glcheck();
			}

			glBindVertexArray(0);
			glcheck();
		}

		static if(Spec.isAnimated)
		void update(float p_delta, Instance[] p_instances) 
		{
			glcheck();
			foreach(ref inst; p_instances)
			{
				if(inst.anim.is_updated && !inst.anim.is_playing)
				{
					continue;
				}

				if(inst.anim.is_playing)
				{
					updateAnimation(p_delta, inst.anim, inst.mesh.bones, inst.mesh.data);
				}

				Mat4 applyParentTransform(ref GLBNode node, ref GLBNode[] nodes) 
				{
					if(node.parent >= 0)
					{
						return applyParentTransform(nodes[node.parent], nodes) * node.computeMatrix();
					}
					else
					{
						return node.computeMatrix();
					}
				}

				foreach(size_t i; 0..inst.mesh.bones.length)
				{
					inst.instanceData.bones[i] = 
						applyParentTransform(inst.anim.bones[i], inst.anim.bones) 
						* inst.mesh.inverseBindMatrices[i].transposed();
				}
			}
			glcheck();
		}

		void clearMeshes()
		{
			glDeleteBuffers(cast(int) vbos.length, vbos.ptr);
			foreach(i; 0..meshes.length)
			{
				meshes[i].clear();
			}
			meshes.clear();
			vbos.clear();
		}
	}

	struct Mesh
	{
		static if(Spec.isAnimated)
		{
			GLBNode[] bones;
			GLBAnimation[] animations;
			Mat4[] inverseBindMatrices;
		}

		ubyte[] data;
		Spec.accessor accessor;
		GLuint vao;

		this(ref System p_system, MeshData p_data, ubyte[] p_bytes, GLuint p_vbo)
		{
			glcheck();

			data = p_bytes;
			accessor = p_data.accessor;

			static if(Spec.isAnimated)
			{
				bones = p_data.bones;
				animations = p_data.animations;
				auto ibmStart = p_data.inverseBindMatrices.byteOffset;
				auto ibmEnd = p_data.inverseBindMatrices.byteLength;
				inverseBindMatrices = (cast(Mat4*) &p_bytes[ibmStart])[0..ibmEnd/Mat4.sizeof];
			}

			glcheck();
			glGenVertexArrays(1, &vao);
			glBindVertexArray(vao);
			p_system.atr.enable();
			p_system.atr.initialize(accessor);
			p_system.atr.disable();
			glBindVertexArray(0);

			glcheck();
		}

		this(ref Mesh rhs) nothrow
		{
			static foreach(field; FieldNameTuple!Mesh)
			{
				mixin(format("this.%s = rhs.%s;", field, field));
			}

			rhs.vao = 0;
		}

		~this()
		{
			clear();
		}

		void clear()
		{
			glDeleteVertexArrays(1, &vao);
			glcheck();
		}
	}

	struct Instance
	{
		Mesh* mesh;
		Uniforms.instance instanceData;

		this(Mesh* p_mesh)
		{
			mesh = p_mesh;
		}

		static if(Spec.isAnimated)
		{
			SkeletalAnimationInstance anim;

			this(Mesh* p_mesh, ref Region p_alloc) 
			{
				mesh = p_mesh;
				instanceData.bones = p_alloc.makeList!Mat4(p_mesh.bones.length);
				anim.bones = p_alloc.makeList!GLBNode(p_mesh.bones.length);
				anim.bones[0..$] = p_mesh.bones[0..$];
				anim.is_playing = false;
				anim.time = 0;
			}

			bool play(string p_anim, bool loop = false)
			{
				return anim.play(p_anim, mesh.animations, loop);
			}

			bool queue(string p_anim, bool loop = false)
			{
				return anim.queue(p_anim, mesh.animations, loop);
			}

			void pause()
			{
				anim.is_playing = false;
			}

			void resume() 
			{
				anim.is_playing = true;
			}

			void restart()
			{
				anim.restart(mesh.bones);
			}
		}
	}
}