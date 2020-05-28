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

import lantana.animation;
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

enum lnt_LogarithmicDepth = false;

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

	static if(lnt_LogarithmicDepth)
	{
		float nearPlane, farPlane;
	}
}

struct DefaultSettings
{
	enum alphaBlend = false;
	enum depthTest = true;
	enum depthWrite = true;
	enum filter = Filter(TexFilter.Linear, TexFilter.MipMaps);
	alias textureType = Color;
}

template GenericMesh(Attrib, Loader, GlobalUniforms=DefaultUniforms, Settings=DefaultSettings)
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
		static if(Spec.isAnimated)
		{
			SkeletalSystem* skeletal;
		}
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
						textures.place(type, loaded.data[byteOffset..byteOffset+byteLength], p_alloc, Settings.filter, false);
					}
				}
				meshes.place(p_alloc, this, mesh, loaded.data, vbo, &textures[$-1]);

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
				mat.setUniform(un.i_transform(), inst.transform.computeMatrix());

				static if(Spec.isAnimated)
				{
					mat.setUniform(un.i_bones(), inst.boneMatrices);
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
			foreach(ref inst; p_instances)
			{
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
					inst.boneMatrices[i] = 
						applyParentTransform(inst.bones[i], inst.bones) 
						* inst.mesh.inverseBindMatrices[i].transposed();
				}
			}
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
			mat4[] inverseBindMatrices;
			FixedMap!(string, ushort) boneIndex;
			FixedMap!(string, SkeletalSystem.Bone[]) animations; 
			System* system;

			GLBNode getBone(string name)
			{
				return bones[boneIndex[name]];
			}
		}

		ubyte[] data;
		Spec.accessor accessor;
		texture* tex_albedo;
		GLuint vao;

		this(ref Region p_alloc, ref System p_system, MeshData p_data, ubyte[] p_bytes, GLuint p_vbo, texture* p_texture)
		{
			glcheck();

			data = p_bytes;
			tex_albedo = p_texture;
			accessor = p_data.accessor;

			static if(Spec.isAnimated)
			{
				system = &p_system;
				bones = p_data.bones;
				animations = FixedMap!(string, SkeletalSystem.Bone[])(p_alloc, cast(uint) p_data.animations.length);

				foreach(const anim; p_data.animations)
				{
					animations[anim.name] = p_alloc.makeList!(SkeletalSystem.Bone)(bones.length*3);
					foreach(ref bone; animations[anim.name])
					{
						bone.translation = Animation!vec3.TrackId.invalid;
						bone.rotation = Animation!quat.TrackId.invalid;
						bone.scale = Animation!vec3.TrackId.invalid;
					}
				}
				foreach(ref anim; p_data.animations)
				{
					foreach(ref channel; anim.channels)
					{
						auto times = anim.bufferViews[channel.timeBuffer].asArray!float(p_bytes);
						auto val = anim.bufferViews[channel.valueBuffer];

						switch(channel.path)
						{
							case GLBAnimationPath.TRANSLATION:
								auto vals = val.asArray!vec3(p_bytes);
								animations[anim.name][channel.targetBone].translation = p_system.skeletal.vectors.addTrack(vals, times);
								break;
							case GLBAnimationPath.SCALE:
								auto vals = val.asArray!vec3(p_bytes);
								animations[anim.name][channel.targetBone].scale = p_system.skeletal.vectors.addTrack(vals, times);
								break;
							case GLBAnimationPath.ROTATION:
								void loadRotation(T)()
								{
									auto vals = p_alloc.makeList!quat(val.count());
									auto rot = val.asArray!(Vector!(T, 4))(p_bytes);

									foreach(i, ref v; vals)
									{
										v = getQuat(rot[i]);
									}
									animations[anim.name][channel.targetBone].rotation = p_system.skeletal.rotations.addTrack(vals, times);

								}
								switch(val.componentType)
								{
									case GLBComponentType.BYTE:
										loadRotation!byte();
										break;
									case GLBComponentType.UNSIGNED_BYTE:
										loadRotation!ubyte();
										break;
									case GLBComponentType.SHORT:
										loadRotation!short();
										break;
									case GLBComponentType.UNSIGNED_SHORT:
										loadRotation!ushort();
										break;
									case GLBComponentType.FLOAT:
										auto floats = val.asArray!vec4(p_bytes);
										auto quats = cast(quat[]) floats;
										foreach(i, ref q; quats)
										{
											quat t = getQuat(floats[i]);
											q = t;
										}
										animations[anim.name][channel.targetBone].rotation = p_system.skeletal.rotations.addTrack(quats, times);
										break;
									default:
										break;
								}
								break;
							default:
								debug writefln("Unsupported animation path: %s", channel.path);
								break;
						}
					}
				}

				auto ibmStart = p_data.inverseBindMatrices.byteOffset;
				auto ibmEnd = p_data.inverseBindMatrices.byteLength;
				inverseBindMatrices = (cast(mat4*) &p_bytes[ibmStart])[0..ibmEnd/mat4.sizeof];
				boneIndex = p_data.boneIndex;
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
			GLBNode[] bones;
			mat4[] boneMatrices;
			BufferRange boneLocationPlayers;
			BufferRange boneRotationPlayers;
			BufferRange boneScalePlayers;

			this(Mesh* p_mesh, Transform p_transform, ref Region p_alloc, ref System p_sys) 
			{
				mesh = p_mesh;
				transform = p_transform;
				boneMatrices = p_alloc.makeList!mat4(p_mesh.bones.length);
				bones = p_alloc.copyMutList(p_mesh.bones);
				
				with(mesh.system.skeletal)			
				{
					// bone translation and scale
					BufferRange v = vectors.allocPlayers(cast(uint) bones.length*2);

					boneLocationPlayers = BufferRange(v.start, v.start + cast(uint) bones.length);
					boneScalePlayers = BufferRange(boneLocationPlayers.end, boneLocationPlayers.end + cast(uint) bones.length);

					// bone rotations
					boneRotationPlayers = rotations.allocPlayers(cast(uint) bones.length);

					foreach(i, ref bone; bones)
					{
						vectors.players[boneLocationPlayers.start + i].output = &(bone.translation);
						vectors.players[boneScalePlayers.start + i].output = &(bone.scale);
						rotations.players[boneRotationPlayers.start + i].output = &(bone.rotation);
					}
				}

			}

			bool play(string p_anim, bool loop = false)
			{
				import std.stdio;
				if(p_anim !in mesh.animations)
				{
					writefln("Unknown animation: %s", p_anim);
					return false;
				}
				writefln("Playing %s", p_anim);
				SkeletalSystem.Bone[] boneTracks = mesh.animations[p_anim];

				with(mesh.system.skeletal)			
				{
					foreach(i, ref bone; bones)
					{
						auto t = &vectors.players[boneLocationPlayers.start + i];
						auto s = &vectors.players[boneScalePlayers.start + i];
						auto r = &rotations.players[boneRotationPlayers.start + i];

						t.trackId = boneTracks[i].translation;
						s.trackId = boneTracks[i].scale;
						r.trackId = boneTracks[i].rotation;

						t.play = true;
						s.play = true;
						r.play = true;

						t.loop = loop;
						s.loop = loop;
						r.loop = loop;

						t.time = 0;
						s.time = 0;
						r.time = 0;
					}
				}
				return true;
			}

			void pause()
			{
				with(mesh.system.skeletal)			
				{
					foreach(i, ref bone; bones)
					{
						auto t = &vectors.players[boneLocationPlayers.start + i];
						auto s = &vectors.players[boneScalePlayers.start + i];
						auto r = &rotations.players[boneRotationPlayers.start + i];

						t.play = false;
						s.play = false;
						r.play = false;
					}
				}
			}

			void resume() 
			{
				with(mesh.system.skeletal)			
				{
					foreach(i, ref bone; bones)
					{
						auto t = &vectors.players[boneLocationPlayers.start + i];
						auto s = &vectors.players[boneScalePlayers.start + i];
						auto r = &rotations.players[boneRotationPlayers.start + i];

						t.play = true;
						s.play = true;
						r.play = true;
					}
				}
			}

			void restart()
			{
				with(mesh.system.skeletal)			
				{
					foreach(i, ref bone; bones)
					{
						auto t = &vectors.players[boneLocationPlayers.start + i];
						auto s = &vectors.players[boneScalePlayers.start + i];
						auto r = &rotations.players[boneRotationPlayers.start + i];

						t.time = 0;
						s.time = 0;
						r.time = 0;
					}
				}
			}
		}
	}
}