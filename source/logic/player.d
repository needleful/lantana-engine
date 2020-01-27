// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.player;

import gl3n.linalg;

import logic.grid;
import logic.input;

enum PlayerState
{
	IDLE,
	MOVE,
	BLOCKED,
	PUSHING,
	MOVE_BACKWARD,
	TURN90_RIGHT,
	TURN90_LEFT,
	TURN180_RIGHT,
	TURN180_LEFT
}
enum PlayerMode
{
	FREE,
	WITH_AXE,
}
struct Player
{
	GridPos pos, pos_target;

	GridDirection dir;
	PlayerState state;
	PlayerState previousState;
	// For visual appeal, the character turns in one direction
	PlayerState previousTurnState;
	PlayerMode mode;

	this(GridPos p_gridPos, GridDirection p_dir = GridDirection.UP, PlayerState p_state = PlayerState.IDLE)  @safe nothrow
	{
		pos = p_gridPos;
		state = p_state;
		pos_target = pos;

		dir = p_dir;
	}

	void update(ref Grid grid, const(Input*) input, const float delta)   @safe nothrow
	{
		// Calculate new state

		// While free, turning only lasts for one frame
		// We're assigning 'state' here to bypass the queueAnimation/playAnimation logic
		if(state == PlayerState.TURN90_LEFT 
			|| state == PlayerState.TURN90_RIGHT 
			|| state == PlayerState.TURN180_LEFT 
			|| state == PlayerState.TURN180_RIGHT)
		{
			state = PlayerState.MOVE;
		}
		previousState = state;
		// !grid.active means the current move has ended
		if(!grid.active)
		{
			PlayerState nextState = PlayerState.IDLE;
			pos = pos_target;

			GridDirection previousDir = dir;
			// Can only move one grid space at a time
			if(input.is_pressed(Input.Action.FORWARD))
			{
				dir = GridDirection.UP;
				nextState = PlayerState.MOVE;
			}
			else if(input.is_pressed(Input.Action.BACK))
			{
				dir = GridDirection.DOWN;
				nextState = PlayerState.MOVE;
			}
			else if(input.is_pressed(Input.Action.RIGHT))
			{
				dir = GridDirection.RIGHT;
				nextState = PlayerState.MOVE;
			}
			else if(input.is_pressed(Input.Action.LEFT))
			{
				dir = GridDirection.LEFT;
				nextState = PlayerState.MOVE;
			}

			if(nextState == PlayerState.MOVE)
			{
				bool blockPushed;
				pos_target = grid.move(pos, dir, true, blockPushed);
				if(pos == pos_target)
				{
					nextState = PlayerState.BLOCKED;
				}
				else if(blockPushed)
				{
					nextState = PlayerState.PUSHING;
				}
			}

			float diff = dir.getRealRotation() - previousDir.getRealRotation();
			if(diff == -270 || diff == 90)
			{
				nextState = PlayerState.TURN90_RIGHT;
				previousTurnState = nextState;
			}
			else if(diff == 270 || diff == -90)
			{
				nextState = PlayerState.TURN90_LEFT;
				previousTurnState = nextState;
			}
			else if(diff == 180 || diff == -180)
			{
				if(previousTurnState == PlayerState.TURN180_LEFT || previousTurnState == PlayerState.TURN90_LEFT)
				{
					nextState = PlayerState.TURN180_LEFT;
				}
				else if(previousTurnState == PlayerState.TURN180_RIGHT || previousTurnState == PlayerState.TURN90_RIGHT)
				{
					nextState = PlayerState.TURN180_RIGHT;
				}
			}

			state = nextState;
		}
	}

	string getAnimation()  @safe nothrow
	{
		switch(state)
		{
			case PlayerState.MOVE:
				return "FreeWalk";

			case PlayerState.TURN90_RIGHT:
				return "FreeTurn90Right";
			case PlayerState.TURN90_LEFT:
				return "FreeTurn90Left";

			case PlayerState.TURN180_RIGHT:
				return "FreeTurn180Right";
			case PlayerState.TURN180_LEFT:
				return "FreeTurn180Left";

			case PlayerState.IDLE:
				goto default;
			default:
				return "FreeIdle";
		}
	}

	vec3 realPosition(ref Grid grid)  @safe nothrow
	{
		return grid.getRealPosition(pos, pos_target);
	}

	float realRotation()  @safe nothrow
	{
		return dir.getRealRotation();
	}
}