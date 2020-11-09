// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.animation.skeletal;

import std.algorithm: endsWith;
debug import std.stdio;
debug import std.format;

import gl3n.interpolate;
import gl3n.linalg;

import lantana.math.transform;
import lantana.file.gltf2;
import lantana.render.mesh.attributes;

struct SkeletalAnimationInstance
{
	GLBNode[] bones;
	mat4[] boneMatrices;
	const(GLBAnimation)* currentAnimation;
	float time;
	bool is_updated;
	bool looping;
	bool is_playing;

	void pause()
	{
		is_playing = false;
	}

	void play_current() 
	{
		is_playing = true;
	}

	/// Play an animation
	/// Returns true if the animation could be started
	bool playAnimation(string p_name, GLBAnimation[] p_animations, bool p_looping = false) 
	{
		is_updated = false;
		foreach(ref a; p_animations)
		{
			if(a.name == p_name)
			{
				currentAnimation = &a;
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

	bool queueAnimation(string p_name, GLBAnimation[] p_animations, bool p_looping = false) 
	{
		if(is_playing)
		{
			return false;
		}
		else 
		{
			return playAnimation(p_name, p_animations, p_looping);
		}
	}

	void restart(GLBNode[] oldBones) 
	{
		time = 0;
		bones[0..$] = oldBones[0..$];
	}
}

public void updateAnimation(float p_delta, ref SkeletalAnimationInstance inst, GLBNode[] oldBones, ubyte[] p_data) 
{
	inst.time += p_delta;
	const(GLBAnimation)* anim = inst.currentAnimation;
	foreach(ref channel; anim.channels)
	{
		auto keyTimes = anim.bufferViews[channel.timeBuffer].asArray!float(p_data);
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
			if(inst.looping)
				inst.restart(oldBones);
			else
				inst.is_playing = false;
		}

		auto valueBuffer = &anim.bufferViews[channel.valueBuffer];
		switch(channel.path)
		{
			case GLBAnimationPath.TRANSLATION:
				auto valueFrames = valueBuffer.asArray!vec3(p_data);
				vec3 current = valueFrames[frame];
				vec3 next = valueFrames[nextframe];
				inst.bones[channel.targetBone].translation = lerp(current, next, interp);
				break;

			case GLBAnimationPath.ROTATION:
				void get_rot(T)() 
				{
					import lantana.math.func;
					quat value;
					auto rotations = valueBuffer.asArray!(Vector!(T, 4))(p_data);

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
				auto valueFrames = valueBuffer.asArray!vec3(p_data);
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