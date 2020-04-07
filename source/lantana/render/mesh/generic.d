// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.render.mesh.generic;

import std.algorithm: endsWith;
debug import std.format;
debug import std.stdio;
import std.traits: FieldNameTuple;

import gl3n.interpolate;
import gl3n.linalg;

import lantana.file.gltf2;
import lantana.file.lgbt;
import lantana.math.transform;

import lantana.render.gl;
import lantana.render.lights;
import lantana.render.material;
import lantana.render.mesh.animation;
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
	alias settings = Settings;

	alias Spec = MeshSpec!(Attrib, Loader);

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

		Mesh* loadMesh(string p_filename, ref Region p_alloc)
		{
			GLBLoadResults!Spec loaded;
			loaded = glbLoad!Spec(p_filename, p_alloc);
			meshes.place(this, loaded, p_alloc);
			return &meshes[$-1];
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

				glDrawElements(
					GL_TRIANGLES, 
					cast(int)inst.mesh.accessor.indices.byteLength,
					inst.mesh.accessor.indices.componentType,
					cast(GLvoid*) inst.mesh.accessor.indices.byteOffset);
			}

			glBindVertexArray(0);
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

				foreach(ulong i; 0..inst.mesh.bones.length)
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
			foreach(i; 0..meshes.length)
			{
				meshes[i].clear();
			}
			meshes.clearNoGC();
		}
	}

	struct Mesh
	{
		alias texture = Texture!(Settings.textureType);

		ubyte[] data;

		static if(Spec.isAnimated)
		{
			GLBNode[] bones;
			GLBAnimation[] animations;
			mat4[] inverseBindMatrices;
		}

		Spec.accessor accessor;

		texture tex_albedo;

		GLuint vbo, vao;

		this(ref System p_parent, GLBLoadResults!Spec p_loaded, ref Region p_alloc) 
		{
			data = p_loaded.data;
			accessor = p_loaded.accessor;

			static if(Spec.isAnimated)
			{
				bones = p_loaded.bones;
				animations = p_loaded.animations;
				auto ibmStart = p_loaded.inverseBindMatrices.byteOffset;
				auto ibmEnd = p_loaded.inverseBindMatrices.byteLength;
				inverseBindMatrices = (cast(mat4*) &data[ibmStart])[0..ibmEnd/mat4.sizeof];
			}

			glcheck();
			glGenBuffers(1, &vbo);
			glGenVertexArrays(1, &vao);

			glBindVertexArray(vao);

			p_parent.atr.enable();

			glBindBuffer(GL_ARRAY_BUFFER, vbo);
			glBufferData(GL_ARRAY_BUFFER, p_loaded.bufferSize, data.ptr, GL_STATIC_DRAW);
			
			p_parent.atr.initialize(accessor);

			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo);

			glBindVertexArray(0);
			p_parent.atr.disable();

			with(accessor.tex_albedo)
			{
				tex_albedo = texture(type, data[byteOffset..byteOffset+byteLength], p_alloc, Settings.filter);
			}

			glcheck();
		}

		this(ref Mesh rhs) @nogc nothrow
		{
			static foreach(field; FieldNameTuple!Mesh)
			{
				mixin(format("this.%s = rhs.%s;", field, field));
			}

			rhs.vao = 0;
			rhs.vbo = 0;
		}

		~this() @nogc
		{
			clear();
		}

		void clear() @nogc
		{
			glDeleteBuffers(1, &vbo);
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
			package AnimationInstance anim;

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
				return anim.playAnimation(p_anim, mesh.animations, loop);
			}

			bool queue(string p_anim, bool loop = false)
			{
				return anim.queueAnimation(p_anim, mesh.animations, loop);
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