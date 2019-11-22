// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.player;

import lanlib.math.vector;

import logic.grid;
import logic.input;


enum Direction
{
	UP,
	DOWN,
	LEFT,
	RIGHT,
}



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
	float timer_move = 0;
	GridPos pos, target;
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
				next_state = State.MOVE;
				target.z += 1;
			}
			else if(input.is_pressed(Input.Action.BACK))
			{
				next_state = State.MOVE;
				target.z -= 1;
			}
			else if(input.is_pressed(Input.Action.RIGHT))
			{
				next_state = State.MOVE;
				target.x += 1;
			}
			else if(input.is_pressed(Input.Action.LEFT))
			{
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

	Vec3 getPos() @nogc @safe nothrow
	{
		return grid.getRealPosition(pos).lerp(
			grid.getRealPosition(target), 
			timer_move/TIME_MOVE
			);
	}

}