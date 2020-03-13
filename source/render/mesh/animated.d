// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh.animated;

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

	@animated
	struct Attributes
	{
		vec3 position;
		vec3 normal;
		vec2 uv;
		vec4 bone_weight;
		uint bone_idx;
	}

	struct Loader
	{
		enum position = "POSITION";
		enum normal = "NORMAL";
		enum uv = "TEXCOORD_0";
		enum bone_weight = "WEIGHTS_0";
		enum bone_idx = "JOINTS_0";
	}

	alias Spec = MeshSpec!(Attributes, Loader);

	Spec.attribType atr;
	OwnedList!AnimatedMesh meshes;
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

		un.bones = mat.getUniformId("bones");

		glcheck();
	}

	AnimatedMesh* loadMesh(string p_filename, ref Region p_alloc)
	{
		GLBLoadResults!Spec loaded;
		loaded = glbLoad!Spec(p_filename, p_alloc);
		loaded = glbLoad!Spec(p_filename, p_alloc);
		
		//if(p_filename.endsWith(".glb"))
		//{
		//}
		//else
		//{
		//	loaded = binaryLoad!GLBAnimatedLoadResults(p_filename, p_alloc);
		//}
		meshes.place(this, loaded.accessor, loaded, p_alloc);
		return &meshes[$-1];
	}

	void update(float p_delta, AnimatedMeshInstance[] p_instances) 
	{
		glcheck();
		debug uint inst_id = 0;
		foreach(ref inst; p_instances)
		{
			if(inst.is_updated && !inst.is_playing)
			{
				continue;
			}
			if(inst.is_playing)
			{
				updateAnimation(p_delta, inst);
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
				inst.boneMatrices[i] = 
					applyParentTransform(inst.bones[i], inst.bones) 
					* inst.mesh.inverseBindMatrices[i].transposed();
			}
		}
		glcheck();
	}

	void render(mat4 projection, ref LightInfo p_lights, AnimatedMeshInstance[] p_instances) 
	{
		glcheck();
		glEnable(GL_CULL_FACE);
		glDisable(GL_BLEND);
		glEnable(GL_DEPTH_TEST);

		mat.enable();
		un.light.set(mat, p_lights);
		mat.setUniform(un.projection, projection);
		mat.setUniform(un.light.palette, 0);
		mat.setUniform(un.tex_albedo, 1);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, p_lights.palette.id);

		glcheck();

		AnimatedMesh* current_mesh = null;
		foreach(ref inst; p_instances)
		{
			glcheck();
			inst.transform.computeMatrix();
			mat.setUniform(un.transform, inst.transform.matrix);
			mat.setUniform(un.bones, inst.boneMatrices);
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

	/// Update the animations of a specific mesh.
	/// Only supports linear interpolation
	private void updateAnimation(float p_delta, ref AnimatedMeshInstance inst) 
	{
		//debug scope(failure)
		//{
		//	writefln("Failed in mesh %s, animation %s", inst.mesh.accessor.name, inst.currentAnimation.name);
		//}
		inst.time += p_delta;
		const(GLBAnimation)* anim = inst.currentAnimation;
		foreach(ref channel; anim.channels)
		{
			auto keyTimes = anim.bufferViews[channel.timeBuffer].asArray!float(inst.mesh.data);
			ulong frame = 0;
			foreach(i; 0..keyTimes.length)
			{
				if(inst.time <= keyTimes[i])
				{
					break;
				}
				frame = i;
			}
			ulong nextframe = (frame + 1) % keyTimes.length;
			float interp;

			if(nextframe > frame)
			{
				float frametime = inst.time - keyTimes[frame];
				if(frametime <= 0)
					interp = 0;
				else
					interp = frametime/(keyTimes[nextframe] - keyTimes[frame]);

				debug import std.format;
				debug assert(interp <= 1 && interp >= 0, 
					format("interp not within [0,1]: %f/(%f - %f) = %f", 
						frametime, keyTimes[nextframe], keyTimes[frame], interp));
			}
			else
			{
				// TODO: interpolate to frame 0 if the animation loops?
				interp = 0;
			}

			// At the last frame
			if(frame == keyTimes.length-1)
			{
				// Restart next frame (TODO: maybe restart this frame?)
				if(inst.looping)
					inst.restart();
				else
					inst.is_playing = false;
			}

			auto valueBuffer = &anim.bufferViews[channel.valueBuffer];
			switch(channel.path)
			{
				case GLBAnimationPath.TRANSLATION:
					auto valueFrames = valueBuffer.asArray!vec3(inst.mesh.data);
					vec3 current = valueFrames[frame];
					vec3 next = valueFrames[nextframe];
					inst.bones[channel.targetBone].translation = lerp(current, next, interp);
					break;

				case GLBAnimationPath.ROTATION:
					void get_rot(T)() 
					{
						import lanlib.math.func;
						quat value;
						auto rotations = valueBuffer.asArray!(Vector!(T, 4))(inst.mesh.data);

						auto current = getQuat(rotations[frame]);
						auto next = getQuat(rotations[nextframe]);
						inst.bones[channel.targetBone].rotation = qlerp(current, next, interp);
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
					auto valueFrames = valueBuffer.asArray!vec3(inst.mesh.data);
					auto current = valueFrames[frame];
					auto next = valueFrames[nextframe];
					inst.bones[channel.targetBone].scale = lerp(current, next, interp);
					break;

				case GLBAnimationPath.WEIGHTS:
					goto default;
				// TODO: support for morph targets?
				default:
					debug writeln("Unsupported animation path: ", channel.path);
					break;
			}
		}
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

struct AnimatedMesh
{
	GLBNode[] bones;
	mat4[] inverseBindMatrices;
	ubyte[] data;
	GLBAnimation[] animations;
	AnimatedMeshSystem.Spec.accessor accessor;
	Texture!Color tex_albedo;
	GLuint vbo, vao;

	this(ref AnimatedMeshSystem p_system, ref AnimatedMeshSystem.Spec.accessor p_accessor, ref GLBLoadResults!(AnimatedMeshSystem.Spec) p_loaded, ref Region p_alloc) 
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

		p_system.atr.enable();

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, p_loaded.bufferSize, data.ptr, GL_STATIC_DRAW);
		
		p_system.atr.initialize(accessor);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo);

		glBindVertexArray(0);
		p_system.atr.disable();

		glcheck();
	}

	this(ref AnimatedMesh rhs)
	{
		bones = rhs.bones;
		inverseBindMatrices = rhs.inverseBindMatrices;
		data = rhs.data;
		animations = rhs.animations;
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
		//if(vao == 0) assert(false, "This should be a fuckin blit!");
		//debug printf("Deleting AnimatedMesh (vao %d)\n", vao);
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
	const(GLBAnimation)* currentAnimation;
	Transform transform;
	float time;
	bool is_updated;
	bool looping;
	bool is_playing;

	this(AnimatedMesh* p_mesh, Transform p_transform, ref Region p_alloc) 
	{
		mesh = p_mesh;
		transform = p_transform;
		boneMatrices = p_alloc.makeList!mat4(p_mesh.bones.length);
		bones = p_alloc.makeList!GLBNode(p_mesh.bones.length);
		bones[0..$] = p_mesh.bones[0..$];
		is_playing = false;
		time = 0;
	}

	bool queueAnimation(string p_name, bool p_looping = false) 
	{
		if(is_playing)
		{
			return false;
		}
		else 
		{
			return playAnimation(p_name, p_looping);
		}
	}

	/// Play an animation
	/// Returns true if the animation could be started
	bool playAnimation(string p_name, bool p_looping = false) 
	{
		is_updated = false;
		foreach(ref anim; mesh.animations)
		{
			if(anim.name == p_name)
			{
				currentAnimation = &anim;
				time = 0;
				is_playing = true;
				looping = p_looping;
				return true;
			}
		}
		debug writeln("Failed to play animation: ", p_name);
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