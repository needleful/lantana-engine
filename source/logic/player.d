// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.player;

import gl3n.interpolate;
import gl3n.linalg;

import logic.grid;
import logic.input;


struct Player
{
	// Time to go from one grid point to another
	enum TIME_MOVE = 0.25;
	enum State
	{
		IDLE,
		MOVE,
	}
	Grid* grid;
	GridPos pos, target;
	float timer_move = 0;
	GridDirection dir;
	State state;

	@disable this();
	this(Grid* grid, GridPos gridPos, State state = State.IDLE) @nogc @safe nothrow
	{
		this.grid = grid;
		this.pos = gridPos;
		this.state = state;
		this.target = this.pos;
	}

	void frame(const ref Input input, const float delta)  @nogc @safe nothrow
	{

		if(state == State.MOVE)
		{
			timer_move += delta;
			if(timer_move >= TIME_MOVE)
			{
				state = State.IDLE;
			}
		}

		if(state == State.IDLE)
		{
			State next_state = State.IDLE;
			pos = target;
			timer_move = 0;
			// Can only move one grid space at a time
			if(input.is_pressed(Input.Action.FORWARD))
			{
				dir = GridDirection.UP;
				next_state = State.MOVE;
				target.z += 1;
			}
			else if(input.is_pressed(Input.Action.BACK))
			{
				dir = GridDirection.DOWN;
				next_state = State.MOVE;
				target.z -= 1;
			}
			else if(input.is_pressed(Input.Action.RIGHT))
			{
				dir = GridDirection.RIGHT;
				next_state = State.MOVE;
				target.x += 1;
			}
			else if(input.is_pressed(Input.Action.LEFT))
			{
				dir = GridDirection.LEFT;
				next_state = State.MOVE;
				target.x -= 1;
			}

			if(!grid.inBounds(target))
			{
				target = pos;
				state = State.IDLE;
			}
			state = next_state;
		}

	}

	vec3 getPos() @nogc @safe nothrow
	{
		return lerp(
			grid.getRealPosition(pos),
			grid.getRealPosition(target), 
			timer_move/TIME_MOVE);
	}

}