// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.animation;

import lantana.ecs.core;
import lantana.math.interpolate;
import lantana.types;

alias ECSSystem = lantana.ecs.core.System;

template Animation(Type)
{
	struct TrackId
	{
		static immutable(TrackId) invalid = TrackId(uint.max);
		mixin StrictAlias!uint;
	}

	struct Track
	{
		Type[] keyVals;
		float[] keyTimes;
	}

	struct PlayerId
	{
		static immutable(PlayerId) invalid = PlayerId(uint.max);
		mixin StrictAlias!uint;
	}

	struct TrackPlayer
	{
		Type* output;
		TrackId trackId;
		float time;
		bool loop;
		bool play;
	}

	@ECSSystem(Track.stringof)
	struct System
	{
		Track[] tracks;
		TrackPlayer[] players;

		TrackId addTrack(Type[] keys, float[] times)
		{
			if(keys.length == 0 || times.length == 0)
			{
				debug assert(false, "Invalid animation track");
				else return TrackId.invalid;
			}

			uint trackLen = cast(uint) tracks.length;

			Track t;
			t.keyVals = keys;
			t.keyTimes = times;

			tracks ~= t;
			return TrackId(trackLen);
		}

		PlayerId addPlayer(Type* output, TrackId track, bool loop)
		{
			uint len = cast(uint) players.length;
			TrackPlayer p;

			p.loop = loop;
			p.trackId = track;
			p.output = output;

			return PlayerId(len);
		}

		BufferRange allocPlayers(uint count)
		{
			uint start = cast(uint)players.length;
			players.length += count;
			uint end = cast(uint) players.length;

			foreach(i; start..end)
			{
				players[i].trackId = TrackId.invalid;
			}

			return BufferRange(start, end);
		}

		void setTrack(PlayerId id, TrackId track)
		{
			players[id].trackId = track;
		}

		void update(float delta)
		{
			uint count = 0;
			foreach(ref player; players)
			{
				if(!player.play || player.trackId == TrackId.invalid)
					continue;
				count ++;
				player.time += delta;

				Track track = tracks[player.trackId];
				ulong frame = 0;
				
				foreach(i; 0..track.keyTimes.length)
				{
					if(player.time <= track.keyTimes[i])
						break;
					frame = i;
				}

				ulong nextFrame = (frame + 1) % track.keyTimes.length;
				float interp;

				if(frame == track.keyTimes.length - 1)
				{
					if(player.loop)
						player.time = 0;
					else
						player.play = false;

				}

				if(nextFrame > frame)
				{
					float ftime = player.time - track.keyTimes[frame];
					if(ftime <= 0)
						interp = 0;
					else
						interp = ftime/(track.keyTimes[nextFrame] - track.keyTimes[frame]);
				}
				else
				{
					interp = 0;
				}

				auto previous = track.keyVals[frame];
				auto next = track.keyVals[nextFrame];

				*(player.output) = interpolate(previous, next, interp);
			}
			import std.stdio;
			//writefln("Updated %d %s", count, Type.stringof);
		}
	}
}

struct SkeletalSystem
{
	struct Bone
	{
		Animation!vec3.TrackId translation;
		Animation!quat.TrackId rotation;
		Animation!vec3.TrackId scale;
	}

	import gl3n.linalg;
	Animation!vec3.System vectors;
	Animation!quat.System rotations;

	void update(float p_delta)
	{
		vectors.update(p_delta);
		rotations.update(p_delta);
	}
}