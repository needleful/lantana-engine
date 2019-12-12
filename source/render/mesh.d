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
import lanlib.util.memory:GpuResource;
import lanlib.types;

import render.Material;

struct StaticMeshInstance
{
	Transform transform;
	StaticMesh* mesh;
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
		assert(mat.can_render());
	}

	StaticMesh* build_mesh(GLBMeshAccessor accessor, ubyte[] data)
	{
		meshes.length += 1;
		meshes[$-1] = StaticMesh(this, accessor, data);
		return &meshes[$-1];
	}

	//StaticMesh[] build_meshes(GLBStaticLoadResults loaded)
	//{
	//	uint start = meshes.length-1;
	//	meshes.length += loaded.accessors.length;
	//	uint end = meshes.length;
	//	// TODO implement
	//}

	void render(mat4 projection, StaticMeshInstance[] instances)
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

	AnimatedMesh* build_mesh(GLBAnimatedAccessor accessor, GLBAnimatedLoadResults loaded)
	{
		meshes.length += 1;
		meshes[$-1] = AnimatedMesh(this, accessor, loaded.inverseBindMatrices, loaded.animations, loaded.bones, loaded.data);
		return &meshes[$-1];
	}

	private void animation_update(float delta, ref AnimatedMeshInstance inst)
	{
		inst.time += delta;
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
	void update(float delta, AnimatedMeshInstance[] instances)
	{
		debug uint inst_id = 0;
		foreach(ref inst; instances)
		{
			if(inst.is_updated && !inst.is_playing)
			{
				continue;
			}
			if(inst.is_playing)
			{
				animation_update(delta, inst);
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

	void render(mat4 projection, AnimatedMeshInstance[] instances)
	{
		glcheck();
		glEnable(GL_CULL_FACE);
		glDisable(GL_BLEND);

		mat.enable();
		mat.set_uniform(un.projection, projection);
		mat.set_uniform(un.light_color, vec3(1));
		mat.set_uniform(un.light_direction, vec3(-0.3, -1, 0.2));
		mat.set_uniform(un.light_ambient, vec3(0.1, 0.05, 0.2));
		mat.set_uniform(un.light_bias, 0.2);
		glcheck();

		AnimatedMesh* current_mesh = null;
		foreach(ref inst; instances)
		{
			inst.transform.compute_matrix();
			mat.set_uniform(un.transform, inst.transform.matrix);
			mat.set_uniform(un.bones, inst.boneMatrices);
			if(current_mesh != inst.mesh)
			{
				current_mesh = inst.mesh;
				glBindVertexArray(current_mesh.vao);
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
	GLuint vbo, vao;

	this(ref AnimatedMeshSystem parent, GLBAnimatedAccessor accessor, GLBBufferView ibmview, GLBAnimation[] animations, GLBNode[] bones, ubyte[] data)
	{
		this.data = data;
		this.bones = bones;
		this.accessor = accessor;
		this.animations = animations;

		inverseBindMatrices = (cast(mat4*)&data[ibmview.byteOffset])[0..ibmview.byteLength/mat4.sizeof];

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

		glVertexAttribIPointer(
			parent.atr.bone_idx,
			accessor.bone_idx.dataType.componentCount,
			accessor.bone_idx.componentType,
			0,
			cast(void*) accessor.bone_idx.byteOffset);

		glVertexAttribPointer(
			parent.atr.bone_weight,
			accessor.bone_weight.dataType.componentCount,
			accessor.bone_weight.componentType,
			GL_TRUE,
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