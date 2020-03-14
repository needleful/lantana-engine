// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh.generic;

import std.algorithm: endsWith;
debug import std.format;
debug import std.stdio;
import std.traits: FieldNameTuple;

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
import render.mesh.animation;
import render.mesh.attributes;
import render.textures;

struct DefaultUniforms
{
	mat4 projection;

	vec3 light_direction;
	float light_bias;
	float area_span;
	float area_ceiling;

	int light_palette;
	int tex_albedo;
}

template GenericMesh(Attrib, Loader, GlobalUniforms=DefaultUniforms)
{
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

	struct System
	{
		Spec.attribType atr;
		OwnedList!Mesh meshes;
		Material mat;
		Uniforms un;

		this(Material p_material) 
		{
			mat = p_material;

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
			glDisable(GL_BLEND);
			glEnable(GL_DEPTH_TEST);

			mat.enable();
			
			p_globals.light_palette = 0;
			p_globals.tex_albedo = 1;

			un.setGlobals(mat, p_globals);

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, p_palette.id);

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
		ubyte[] data;

		static if(Spec.isAnimated)
		{
			GLBNode[] bones;
			GLBAnimation[] animations;
			mat4[] inverseBindMatrices;
		}

		Spec.accessor accessor;

		Texture!Color tex_albedo;

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
				tex_albedo = Texture!Color(true, type, data[byteOffset..byteOffset+byteLength], p_alloc);
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