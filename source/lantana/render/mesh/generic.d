// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.render.mesh.generic;

import std.algorithm: endsWith;
import std.format;
debug import std.stdio;
import std.traits: FieldNameTuple;

import gl3n.interpolate;
import gl3n.linalg;

import lantana.animation.skeletal;

import lantana.file.gltf2;
import lantana.file.lgbt;
import lantana.math.transform;

import lantana.render.gl;
import lantana.render.lights;
import lantana.render.material;
import lantana.render.mesh.attributes;
import lantana.render.textures;

import lantana.types;

struct DefaultUniforms
{
	mat4 projection;

	vec3 light_direction;
	float light_bias;
	float area_span;
	float area_ceiling;
	float gamma;

	int light_palette;
	int tex_albedo;

	float nearPlane, farPlane;
}

struct DefaultSettings
{
	enum alphaBlend = false;
	enum depthTest = true;
	enum depthWrite = true;
	enum filter = Filter(TexFilter.Linear, TexFilter.MipMaps);
	alias textureType = Color;
}

template GenericMesh(Attrib, Loader, GlobalUniforms=DefaultUniforms, Settings = DefaultSettings)
{
	alias texture = Texture!(Settings.textureType);

	alias Spec = MeshSpec!(Attrib, Loader);
	private alias MeshData = GLBLoadResults!Spec.MeshData;

	struct InstanceUniforms
	{
		mat4 transform;
		static if(Spec.isAnimated)
		{
			mat4[] bones;
		}
	}

	alias Uniforms = UniformT!(GlobalUniforms, InstanceUniforms);

	enum hasLightPalette = __traits(compiles, {
		Uniforms.global g;
		g.light_palette = 0;
	});

	struct System
	{
		Spec.attribType atr;
		OwnedList!Mesh meshes;
		OwnedList!GLuint vbos;
		OwnedList!texture textures;

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

		void reserveMeshes(ref Region p_alloc, uint p_count)
		{
			meshes = p_alloc.makeOwnedList!Mesh(p_count);
			vbos = p_alloc.makeOwnedList!GLuint(p_count);
			textures = p_alloc.makeOwnedList!texture(p_count);
		}

		Mesh*[string] loadMeshes(string p_filename, ref Region p_alloc)
		{
			glcheck();

			GLBLoadResults!Spec loaded;
			loaded = glbLoad!Spec(p_filename, p_alloc);

			GLuint vbo;
			glGenBuffers(1, &vbo);
			glBindBuffer(GL_ARRAY_BUFFER, vbo);
			glBufferData(GL_ARRAY_BUFFER, loaded.bufferSize, loaded.data.ptr, GL_STATIC_DRAW);
			vbos ~= vbo;

			GLBImage currentImage;
			Mesh*[string] result;
			foreach(name, mesh; loaded.meshes)
			{
				if(currentImage != mesh.accessor.tex_albedo)
				{
					currentImage = mesh.accessor.tex_albedo;
					with(mesh.accessor.tex_albedo)
					{
						textures.place(type, loaded.data[byteOffset..byteOffset+byteLength], p_alloc, Settings.filter);
					}
				}
				meshes.place(this, mesh, loaded.data, vbo, &textures[$-1]);

				result[name] = &meshes[$-1];
			}
			glcheck();
			return result;
		}

		void render(ref Uniforms.global p_globals, ref Texture!Color p_palette, Instance[] p_instances)
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
			static if(hasLightPalette)
			{
				p_globals.light_palette = 0;
				glActiveTexture(GL_TEXTURE0);
				glBindTexture(GL_TEXTURE_2D, p_palette.id);
			}
			glcheck();
			p_globals.tex_albedo = 1;

			un.setGlobals(mat, p_globals);

			GLuint current_vao = 0;
			foreach(ref inst; p_instances)
			{
				glcheck();
				inst.transform.computeMatrix();
				mat.setUniform(un.i_transform(), inst.transform.matrix);

				static if(Spec.isAnimated)
				{
					mat.setUniform(un.i_bones(), inst.anim.boneMatrices);
				}

				if(current_vao != inst.mesh.vao)
				{
					current_vao = inst.mesh.vao;
					glBindVertexArray(current_vao);

					glActiveTexture(GL_TEXTURE1);
					glBindTexture(GL_TEXTURE_2D, inst.mesh.tex_albedo.id);
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
			debug uint inst_id = 0;
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

				mat4 applyParentTransform(ref GLBNode node, ref GLBNode[] nodes) 
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
					inst.anim.boneMatrices[i] = 
						applyParentTransform(inst.anim.bones[i], inst.anim.bones) 
						* inst.mesh.inverseBindMatrices[i].transposed();
				}
			}
			glcheck();
		}

		void clearMeshes() @nogc
		{
			glDeleteBuffers(vbos.length, vbos.ptr);
			foreach(i; 0..meshes.length)
			{
				meshes[i].clear();
			}
			meshes.clearNoGC();
			vbos.clearNoGC();
		}
	}

	struct Mesh
	{
		static if(Spec.isAnimated)
		{
			GLBNode[] bones;
			GLBAnimation[] animations;
			mat4[] inverseBindMatrices;
		}

		ubyte[] data;
		Spec.accessor accessor;
		texture* tex_albedo;
		GLuint vao;

		this(ref System p_system, MeshData p_data, ubyte[] p_bytes, GLuint p_vbo, texture* p_texture)
		{
			glcheck();

			data = p_bytes;
			tex_albedo = p_texture;
			accessor = p_data.accessor;

			static if(Spec.isAnimated)
			{
				bones = p_data.bones;
				animations = p_data.animations;
				auto ibmStart = p_data.inverseBindMatrices.byteOffset;
				auto ibmEnd = p_data.inverseBindMatrices.byteLength;
				inverseBindMatrices = (cast(mat4*) &p_bytes[ibmStart])[0..ibmEnd/mat4.sizeof];
			}

			glcheck();
			glGenVertexArrays(1, &vao);
			glBindVertexArray(vao);
			p_system.atr.enable();

			glBindBuffer(GL_ARRAY_BUFFER, p_vbo);
			p_system.atr.initialize(accessor);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, p_vbo);

			glBindVertexArray(0);
			p_system.atr.disable();

			glcheck();
		}

		this(ref Mesh rhs) @nogc nothrow
		{
			static foreach(field; FieldNameTuple!Mesh)
			{
				mixin(format("this.%s = rhs.%s;", field, field));
			}

			rhs.vao = 0;
		}

		~this() @nogc
		{
			clear();
		}

		void clear() @nogc
		{
			glDeleteVertexArrays(1, &vao);
			glcheck();
		}
	}

	struct Instance
	{
		Transform transform;
		Mesh* mesh;

		this(Mesh* p_mesh, Transform p_transform)
		{
			mesh = p_mesh;
			transform = p_transform;
		}

		static if(Spec.isAnimated)
		{
			SkeletalAnimationInstance anim;

			this(Mesh* p_mesh, Transform p_transform, ref Region p_alloc) 
			{
				mesh = p_mesh;
				transform = p_transform;
				anim.boneMatrices = p_alloc.makeList!mat4(p_mesh.bones.length);
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