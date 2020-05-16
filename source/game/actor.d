// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.actor;

import std.math : abs, sgn;

import gl3n.linalg : vec2, vec3;

import lantana.render.mesh.animation;
import lantana.types : ivec2;

import game.map;

struct ActionState
{
	start,
	inProgress,
	completed
}

struct Actor
{
	// Walking speed in meters per second
	enum speed = 1.4;

	// Where the actor wants to go
	ivec2[] path;

	// The actor's current room
	Room* room;

	// Sequencing animations for rendering
	AnimationSequence* sequence;

	// The actor's position on the room grid
	ivec2 gridPos;

	// The actor's world position
	private vec3 realPos;

	// Distance covered to the next point on the path
	private float coveredDistance, targetDistance;

	// Current direction
	Grid.Dir direction;

	// State of the current action
	ActionState status;

	this(Room* p_room, ivec2 p_gridPos = ivec2(0))
	{
		gridPos = p_gridPos;
		coveredDistance = 0;
		room = p_room;
		realPos = room.getWorldPosition(gridPos);
		status = ActionState.completed;
	}

	bool approach(ivec2 target)
	{
		if(gridPos == target)
		{
			return true;
		}

		auto res = room.grid.navigate(direction, gridPos, target, path);
		if(res)
		{
			if(!getTargetDir())
			{
				sequence.clear();
				sequence.add("Walk");
				sequence.loopFinalAnimation = true;
				sequence.restart();
			}
		}
		else
		{
			sequence.clear();
			sequence.add("IdleStanding");
			sequence.loopFinalAnimation = true;
			sequence.restart();
		}
		status = ActionState.inProgress;
		return res;
	}

	void update(float delta)
	{
		if(status == ActionState.completed)
			return;
		if(path.length == 0)
		{
			status = ActionState.completed;
			coveredDistance = 0;
			if(sequence.sequence.length == 0)
			{
				sequence.add("IdleStanding");
				sequence.loopFinalAnimation = true;
				sequence.restart();
			}
			return;
		}

		vec2 dir = vec2(path[0]-gridPos);
		dir = dir.normalized();

		vec3 move = vec3(dir.x, 0, dir.y)*speed*delta;
		coveredDistance += speed*delta;

		if(coveredDistance >= targetDistance)
		{
			gridPos = path[0];
			realPos = room.getWorldPosition(gridPos);
			coveredDistance = 0;
			path = path[1..$];

			getTargetDir();
		}
		else
		{
			realPos += move;
		}
	}

	vec3 worldPos()
	{
		return realPos;
	}

	float facingAngle()
	{
		return Grid.dirAngles[direction];
	}

	private bool getTargetDir()
	{
		sequence.loopFinalAnimation = true;
		if(path.length == 0)
			return false;

		ivec2 dir = path[0]-gridPos;
		float angle1 = Grid.dirAngles[direction];
		Grid.Dir oldDir = direction;

		direction = fromVector(dir);
		float angle2 = Grid.dirAngles[direction];
		targetDistance = dir.length();

		float turn = angle1 - angle2;

		if(turn != 0)
		{
			turn = (turn + sgn(turn)*180) % 360 - sgn(turn)*180;

			import std.format;
			with(sequence)
			{
				clear();
				add(format("Turn%s%s", abs(turn), turn < 0? "Right" : "Left"));

				// Sync animation to start on other foot, depending on the last frame of the turning animation
				if(abs(turn) >= 134) turn *= -1; // Flip sign for wide turns
				float stime = (turn < 0) ? 0 : (8/30.0);
				add("Walk", stime);
				restart();
			}
			return true;
		}
		return false;
	}
}