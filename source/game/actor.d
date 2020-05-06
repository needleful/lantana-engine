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
	// Walking speed in meters per second
	enum speed = 1.5;

	// Where the actor wants to go
	ivec2[] plan;

	// The actor's current room
	Room* room;

	// The actor's position on the room grid
	ivec2 gridPos;

	// The actor's world position
	private vec3 realPos;

	// Distance covered to the next point on the plan
	private float coveredDistance, targetDistance;

	// Current direction
	Grid.Dir direction;

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

		auto res = room.grid.navigate(direction, gridPos, target, plan);
		if(res)
			getTargetDir();
		return res;
	}

	void update(float delta)
	{
		if(plan.length == 0)
		{
			coveredDistance = 0;
			return;
		}

		vec2 dir = vec2(plan[0]-gridPos);
		dir = dir.normalized();

		vec3 move = vec3(dir.x, 0, dir.y)*speed*delta;
		coveredDistance += speed*delta;

		if(coveredDistance >= targetDistance)
		{
			gridPos = plan[0];
			realPos = room.getWorldPosition(gridPos);
			coveredDistance = 0;
			plan = plan[1..$];

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

	private void getTargetDir()
	{
		if(plan.length == 0)
			return;
		ivec2 dir = plan[0]-gridPos;
		direction = fromVector(dir);
		targetDistance = dir.length();
		import std.stdio;
		writeln(direction);
	}
}