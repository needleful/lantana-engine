// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.actor;

import std.math : abs, sgn;
import std.stdio;

import gl3n.linalg : vec2, vec3;
import swi.prolog;

import lantana.render.mesh;
import lantana.types : ivec2;

import game.map;

struct Action
{
	static atom_t
		cook, //0
		sit,  //0
		stand,//0
		drop, //1
		move, //2
		eat,  //1
		get;  //1

	atom_t name;
	atom_t[2] arguments;
	int arity;

	static void loadAtoms()
	{
		cook = PL_new_atom("cook");
		sit = PL_new_atom("sit");
		stand = PL_new_atom("stand");
		drop = PL_new_atom("drop");
		move = PL_new_atom("move");
		eat = PL_new_atom("eat");
		get = PL_new_atom("get");
	}
}

struct Actor
{
	enum State
	{
		idle,
		inProgress,
		starting,
		failed
	}
	// Walking speed in meters per second
	enum speed = 1.4;

	// Where the actor wants to go
	ivec2[] path;

	// The actor's current room
	Room* room;

	// Sequencing animations for rendering
	AnimMesh.Instance* meshInst;

	// The actor's position on the room grid
	ivec2 gridPos;

	// The actor's world position
	private vec3 realPos;

	// Distance covered to the next point on the path
	private float coveredDistance, targetDistance;

	// Current direction
	Grid.Dir direction;

	Action currentAction;

	// State of the current action
	State state;

	this(Room* p_room, ivec2 p_gridPos = ivec2(0))
	{
		gridPos = p_gridPos;
		coveredDistance = 0;
		room = p_room;
		realPos = room.getWorldPosition(gridPos);
		state = State.idle;
	}

	void update(float delta)
	{
		if((state == State.idle || state == State.failed))
		{
			meshInst.play("IdleStanding", true);
			return;
		}
		else if(state == State.starting)
			start();
		else if(currentAction.name == Action.move)
		{
			if(path.length == 0)
			{
				state = State.idle;
				coveredDistance = 0;
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
	}
	bool approach(atom_t usable)
	{
		if(!room.has(usable))
		{
			return false;
		}
		else
		{
			return approach(room.usablePos(usable));
		}
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
				meshInst.play("Walk", true);
			}
			state = State.inProgress;
		}
		return res;
	}

	private void start()
	{
		bool res = false;
		if(currentAction.name == Action.move)
			res = approach(currentAction.arguments[1]);
		else if(currentAction.name == Action.sit)
		{
			meshInst.play("Sit");
			state = State.inProgress;
			res = true;
		}
		else
			printf("Action not implemented: %s/%d\n", PL_atom_chars(currentAction.name), currentAction.arity);
		if(!res)
			state = State.failed;
	}

	vec3 worldPos()
	{
		return realPos;
	}

	float facingAngle()
	{
		return Grid.dirAngles[direction];
	}

	void setAction(Action a)
	{
		assert(state != State.inProgress);
		currentAction = a;
		state = State.starting;
	}

	private bool getTargetDir()
	{
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
			meshInst.play(format("Turn%s%s", abs(turn), turn < 0? "Right" : "Left"));
			return true;
		}
		return false;
	}
}