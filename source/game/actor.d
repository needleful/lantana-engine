// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.actor;

import std.math : abs;

import gl3n.linalg : vec2, vec3;
import lantana.types : ivec2;

import game.map;

struct Actor
{
	enum State
	{
		idle,
		walking,
		turning
	}
	// Walking speed in meters per second
	enum speed = 1.4;

	// Where the actor wants to go
	ivec2[] path;

	string queuedAnimation = "";

	// The actor's current room
	Room* room;

	// The actor's position on the room grid
	ivec2 gridPos;

	// The actor's world position
	private vec3 realPos;

	// Distance covered to the next point on the path
	private float coveredDistance, targetDistance;

	// Current direction
	Grid.Dir direction;

	bool loopAnimation = false;
	State state = State.idle;
	bool forceUpdate = false;

	this(Room* p_room)
	{
		coveredDistance = 0;
		room = p_room;
		realPos = room.getWorldPosition(gridPos);
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
			getTargetDir();
			queuedAnimation = "WalkCycle";
			loopAnimation = true;
			forceUpdate = true;
		}
		else
		{
			queuedAnimation = "IdleStanding";
			loopAnimation = true;
			forceUpdate = true;
		}
		return res;
	}

	void update(float delta)
	{
		if(path.length == 0)
		{
			coveredDistance = 0;
			return;
		}
		if(state == State.turning)
		{
			state = State.walking;
		}
		else if(state == State.walking)
		{
			queuedAnimation = "WalkCycle";
			loopAnimation = true;
			forceUpdate = false;
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

	private void getTargetDir()
	{
		if(path.length == 0)
			return;
		ivec2 dir = path[0]-gridPos;
		float angle1 = Grid.dirAngles[direction];
		direction = fromVector(dir);
		float angle2 = Grid.dirAngles[direction];

		targetDistance = dir.length();
		if((angle1 - angle2) % 360 == -45)
		{
			queuedAnimation = "Turn45Right";
			loopAnimation = false;
			forceUpdate = true;
		}
		else if((angle1 - angle2) % 360 == 45)
		{
			queuedAnimation = "Turn45Left";
			loopAnimation = false;
			forceUpdate = true;
		}

		if(angle1 != angle2)
		{
			state = State.turning;
		}
	}
}