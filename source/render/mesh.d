// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh;

debug import std.stdio;
debug import std.format;

import gl3n.linalg;

import lanlib.math.transform;
import lanlib.formats.gltf2;
import lanlib.util.gl;
import lanlib.util.memory;
import lanlib.types;

import render.lights;
import render.material;
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
		AttribId position, normal, uv;
	}

	Attributes atr;
	StaticMesh[] meshes;
	Material mat;
	Uniforms un;

	this(uint p_reserved_count)
	{
		mat = loadMaterial("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag");

		atr.position = mat.get_attrib_id("position");
		atr.normal = mat.get_attrib_id("normal");
		atr.uv = mat.get_attrib_id("uv");
		un.transform = mat.get_uniform_id("transform");
		un.projection = mat.get_uniform_id("projection");
		un.tex_albedo = mat.get_uniform_id("tex_albedo");

		un.light = LightUniforms(mat);

		meshes.reserve(p_reserved_count);

		glcheck();
		assert(mat.can_render());
	}

	StaticMesh* load_mesh(string p_filename, ILanAllocator p_allocator)
	{
		meshes.length += 1;
		auto loaded = glb_load(p_filename, p_allocator);
		meshes[$-1] = StaticMesh(this, loaded.accessors[0], loaded.data, loaded.bufferSize, p_allocator);
		return &meshes[$-1];
	}
	
	void render(mat4 p_projection, ref LightInfo p_lights, StaticMeshInstance[] p_instances)
	{
		glcheck();
		glEnable(GL_CULL_FACE);
		glDisable(GL_BLEND);
		glEnable(GL_DEPTH_TEST);

		mat.enable();
		mat.set_uniform(un.projection, p_projection);
		mat.set_uniform(un.light.palette, 0);
		mat.set_uniform(un.tex_albedo, 1);

		un.light.set(mat, p_lights);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, p_lights.palette.id);

		GLuint current_vao = 0;
		foreach(ref inst; p_instances)
		{
			inst.transform.compute_matrix();
			mat.set_uniform(un.transform, inst.transform.matrix);

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
}

struct StaticMesh
{
	ubyte[] data;
	GLBMeshAccessor accessor;
	Texture!Color tex_albedo;
	GLuint vbo, vao;

	this(ref StaticMeshSystem p_parent, GLBMeshAccessor p_accessor, ubyte[] p_data, uint p_bufferSize, ILanAllocator p_alloc)
	{
		data = p_data;
		accessor = p_accessor;

		glcheck();
		glGenBuffers(1, &vbo);
		glGenVertexArrays(1, &vao);

		glBindVertexArray(vao);

		glEnableVertexAttribArray(p_parent.atr.position);
		glEnableVertexAttribArray(p_parent.atr.normal);
		glEnableVertexAttribArray(p_parent.atr.uv);

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, p_bufferSize, data.ptr, GL_STATIC_DRAW);
		
		glVertexAttribPointer(
			p_parent.atr.normal,
			accessor.normals.dataType.componentCount,
			accessor.normals.componentType,
			GL_FALSE,
			0,
			cast(void*) accessor.normals.byteOffset);

		glVertexAttribPointer(
			p_parent.atr.position,
			accessor.positions.dataType.componentCount,
			accessor.positions.componentType,
			GL_FALSE,
			0,
			cast(void*) accessor.positions.byteOffset);

		glVertexAttribPointer(
			p_parent.atr.uv,
			accessor.uv.dataType.componentCount,
			accessor.uv.componentType,
			GL_FALSE,
			0,
			cast(void*) accessor.uv.byteOffset);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo);

		glBindVertexArray(0);
		glDisableVertexAttribArray(p_parent.atr.position);
		glDisableVertexAttribArray(p_parent.atr.normal);
		glDisableVertexAttribArray(p_parent.atr.uv);

		with(p_accessor.tex_albedo)
		{
			tex_albedo = Texture!Color(true, type, p_data[byteOffset..byteOffset+byteLength], p_alloc);
		}

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

struct StaticMeshInstance
{
	Transform transform;
	StaticMesh* mesh;
}

struct AnimatedMeshSystem
{
	struct Uniforms
	{
		// Vertex uniforms
		UniformId transform, projection, bones;
		// Texture uniforms
		UniformId tex_albedo;
		// Light Uniforms
		LightUniforms light;
	}
	struct Attributes
	{
		AttribId position, normal, uv, bone_weight, bone_idx;
	}

	Attributes atr;
	AnimatedMesh[] meshes;
	Material mat;
	Uniforms un;

	this(uint p_reserved_count)
	{
		mat = loadMaterial("data/shaders/animated3d.vert", "data/shaders/material3d.frag");

		atr.position = mat.get_attrib_id("position");
		atr.normal = mat.get_attrib_id("normal");
		atr.uv = mat.get_attrib_id("uv");
		atr.bone_weight = mat.get_attrib_id("bone_weight");
		atr.bone_idx = mat.get_attrib_id("bone_idx");

		un.transform = mat.get_uniform_id("transform");
		un.projection = mat.get_uniform_id("projection");
		un.tex_albedo = mat.get_uniform_id("tex_albedo");
		un.light = LightUniforms(mat);

		un.bones = mat.get_uniform_id("bones");

		meshes.reserve(p_reserved_count);

		glcheck();
	}

	AnimatedMesh* load_mesh(string p_filename, ILanAllocator p_allocator)
	{
		auto loaded = glb_load!true(p_filename, p_allocator);
		meshes.length += 1;
		meshes[$-1] = AnimatedMesh(this, loaded.accessors[0], loaded, p_allocator);
		return &meshes[$-1];
	}

	private void animation_update(float p_delta, ref AnimatedMeshInstance inst)
	{
		inst.time += p_delta;
		const(GLBAnimation*) anim = &inst.currentAnimation;
		foreach(channel; anim.channels)
		{
			float[] keyTimes = anim.bufferViews[channel.timeBuffer].asArray!float(inst.mesh.data);
			ulong frame = 0;
			foreach(i; 0..keyTimes.length)
			{
				if(inst.time <= keyTimes[i])
				{
					break;
				}
				frame = i;
			}

			// Got to last frame
			if(frame == keyTimes.length-1)
			{
				if(inst.looping)
				{
					// Restart next frame (TODO: maybe restart this frame?)
					inst.restart();
				}
				else
				{
					inst.is_playing = false;
				}
			}

			auto valueBuffer = anim.bufferViews[channel.valueBuffer];
			switch(channel.path)
			{
				case GLBAnimationPath.TRANSLATION:
					vec3[] valueFrames = valueBuffer.asArray!vec3(inst.mesh.data);
					inst.bones[channel.targetBone].translation = valueFrames[frame];
					break;
				case GLBAnimationPath.ROTATION:
					void get_rot(T)()
					{
						auto value = valueBuffer.asArray!(Vector!(T, 4))(inst.mesh.data)[frame];
						inst.bones[channel.targetBone].rotation = quat(
							glb_convert!(float, T)(value.w),
							glb_convert!(float, T)(value.x),
							glb_convert!(float, T)(value.y),
							glb_convert!(float, T)(value.z)
						);
					}
					switch(valueBuffer.componentType)
					{
						case GLBComponentType.BYTE:
							get_rot!byte();
							break;
						case GLBComponentType.UNSIGNED_BYTE:
							get_rot!ubyte();
							break;
						case GLBComponentType.SHORT:
							get_rot!short();
							break;
						case GLBComponentType.UNSIGNED_SHORT:
							get_rot!ushort();
							break;
						case GLBComponentType.FLOAT:
							get_rot!float();
							break;
						default:
							break;
					}
					break;
				case GLBAnimationPath.SCALE:
					vec3[] valueFrames = valueBuffer.asArray!vec3(inst.mesh.data);
					inst.bones[channel.targetBone].scale = valueFrames[frame];
					break;
				case GLBAnimationPath.WEIGHTS:
				// TODO: support for morph targets?
				default:
					debug writeln("Unsupported animation path: ", channel.path);
					break;
			}
		}
	} 
	void update(float p_delta, AnimatedMeshInstance[] p_instances)
	{
		debug uint inst_id = 0;
		foreach(ref inst; p_instances)
		{
			if(inst.is_updated && !inst.is_playing)
			{
				continue;
			}
			if(inst.is_playing)
			{
				animation_update(p_delta, inst);
			}
			mat4 applyParentTransform(GLBNode node, ref GLBNode[] nodes)
			{
				if(node.parent >= 0)
				{
					return applyParentTransform(nodes[node.parent], nodes) * node.compute_matrix();
				}
				else
				{
					return node.compute_matrix();
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

	void render(mat4 projection, ref LightInfo p_lights, AnimatedMeshInstance[] p_instances)
	{
		glcheck();
		glEnable(GL_CULL_FACE);
		glDisable(GL_BLEND);
		glEnable(GL_DEPTH_TEST);

		mat.enable();
		un.light.set(mat, p_lights);
		mat.set_uniform(un.projection, projection);
		mat.set_uniform(un.light.palette, 0);
		mat.set_uniform(un.tex_albedo, 1);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, p_lights.palette.id);

		glcheck();

		AnimatedMesh* current_mesh = null;
		foreach(ref inst; p_instances)
		{
			inst.transform.compute_matrix();
			mat.set_uniform(un.transform, inst.transform.matrix);
			mat.set_uniform(un.bones, inst.boneMatrices);
			if(current_mesh != inst.mesh)
			{
				current_mesh = inst.mesh;
				glBindVertexArray(current_mesh.vao);

				glActiveTexture(GL_TEXTURE1);
				glBindTexture(GL_TEXTURE_2D, current_mesh.tex_albedo.id);
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
	GLBNode[] bones;
	mat4[] inverseBindMatrices;
	ubyte[] data;
	GLBAnimation[] animations;
	GLBAnimatedAccessor accessor;
	Texture!Color tex_albedo;
	GLuint vbo, vao;

	this(ref AnimatedMeshSystem p_system, GLBAnimatedAccessor p_accessor, GLBAnimatedLoadResults p_loaded, ILanAllocator p_alloc)
	{
		data = p_loaded.data;
		bones = p_loaded.bones;
		accessor = p_accessor;
		animations = p_loaded.animations;
		with(p_accessor.tex_albedo)
		{
			tex_albedo = Texture!Color(true, type, p_loaded.data[byteOffset..byteOffset+byteLength], p_alloc);
		}

		auto ibmStart = p_loaded.inverseBindMatrices.byteOffset;
		auto ibmEnd = p_loaded.inverseBindMatrices.byteLength;
		inverseBindMatrices = (cast(mat4*) &data[ibmStart])[0..ibmEnd/mat4.sizeof];

		glcheck();
		glGenBuffers(1, &vbo);
		glGenVertexArrays(1, &vao);

		glBindVertexArray(vao);

		glEnableVertexAttribArray(p_system.atr.position);
		glEnableVertexAttribArray(p_system.atr.normal);
		glEnableVertexAttribArray(p_system.atr.uv);
		glEnableVertexAttribArray(p_system.atr.bone_weight);
		glEnableVertexAttribArray(p_system.atr.bone_idx);

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, p_loaded.bufferSize, data.ptr, GL_STATIC_DRAW);
		
		glVertexAttribPointer(
			p_system.atr.normal,
			accessor.normals.dataType.componentCount,
			accessor.normals.componentType,
			GL_FALSE,
			0,
			cast(void*) accessor.normals.byteOffset);

		glVertexAttribPointer(
			p_system.atr.position,
			accessor.positions.dataType.componentCount,
			accessor.positions.componentType,
			GL_FALSE,
			0,
			cast(void*) accessor.positions.byteOffset);

		glVertexAttribPointer(
			p_system.atr.uv,
			accessor.uv.dataType.componentCount,
			accessor.uv.componentType,
			GL_FALSE,
			0,
			cast(void*) accessor.uv.byteOffset);

		glVertexAttribIPointer(
			p_system.atr.bone_idx,
			accessor.bone_idx.dataType.componentCount,
			accessor.bone_idx.componentType,
			0,
			cast(void*) accessor.bone_idx.byteOffset);

		glVertexAttribPointer(
			p_system.atr.bone_weight,
			accessor.bone_weight.dataType.componentCount,
			accessor.bone_weight.componentType,
			GL_TRUE,
			0,
			cast(void*) accessor.bone_weight.byteOffset);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo);

		glBindVertexArray(0);
		glDisableVertexAttribArray(p_system.atr.position);
		glDisableVertexAttribArray(p_system.atr.normal);
		glDisableVertexAttribArray(p_system.atr.uv);
		glDisableVertexAttribArray(p_system.atr.bone_weight);
		glDisableVertexAttribArray(p_system.atr.bone_idx);

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

struct AnimatedMeshInstance
{
	GLBNode[] bones;
	mat4[] boneMatrices;
	AnimatedMesh* mesh;
	GLBAnimation currentAnimation;
	Transform transform;
	float time;
	bool is_updated;
	bool looping;
	bool is_playing;

	this(AnimatedMesh* p_mesh, Transform p_transform, ILanAllocator p_alloc)
	{
		mesh = p_mesh;
		transform = p_transform;
		boneMatrices = p_alloc.make_list!mat4(p_mesh.bones.length);
		bones = p_alloc.make_list!GLBNode(p_mesh.bones.length);
		bones[0..$] = p_mesh.bones[0..$];
		is_playing = false;
		time = 0;
	}

	/// Play an animation
	/// Returns true if the animation could be started
	bool play_animation(string name, bool looping = false)
	{
		debug writeln("Playing animation: ", name);
		is_updated = false;
		foreach(anim; mesh.animations)
		{
			debug writeln("->\t", anim.name);
			if(anim.name == name)
			{
				currentAnimation = anim;
				time = 0;
				is_playing = true;
				this.looping = looping;
				return true;
			}
		}
		debug writeln("Failed to play animation: ", name);
		is_playing = false;
		return false;
	}

	void pause()
	{
		is_playing = false;
	}

	void play_current()
	{
		is_playing = true;
	}

	void restart()
	{
		time = 0;
		bones[0..$] = mesh.bones[0..$];
	}
}