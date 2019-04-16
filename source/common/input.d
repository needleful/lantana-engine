// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module common.input;

debug
{
	import std.stdio;
}

import common.math.vector;

struct Input
{
	enum Action
	{
		UP,
		DOWN,
		LEFT,
		RIGHT,
		JUMP,
		PAUSE,
		ACTION_COUNT,
		UNKNOWN
	}
	enum Status
	{
		UP,
		DOWN,
		JUST_PRESSED,
		JUST_RELEASED,
	}
	// Currently held position of sticks
	Vec2 analog_left, analog_right;
	// Relative mouse movement since last frame
	Vec2 mouse_movement;
	// Status of all buttons
	Status[Action.ACTION_COUNT] status;

	void press(Action a)
	{
		if(status[a] == Status.JUST_PRESSED || status[a] == Status.DOWN)
		{
			//printf("pressed %d [%d, pressed]\n", a, status[a]);
			status[a] = Status.DOWN;
		}
		else
		{
			//printf("pressed %d [%d, released]\n", a, status[a]);
			status[a] = Status.JUST_PRESSED;
		}
	}

	void release(Action a)
	{
		if(status[a] == Status.JUST_RELEASED || status[a] == Status.UP)
		{
			status[a] = Status.UP;
		}
		else
		{
			status[a] = Status.JUST_RELEASED;
		}
	}

	// Reset input, for example when re-entering the window
	void clear()
	{
		analog_left = Vec2(0,0);
		analog_right = Vec2(0,0);
		mouse_movement = Vec2(0,0);
		foreach(ref Status s; status)
		{
			s = Status.UP;
		}
	}

	const bool is_pressed(Action a)
	{
		return status[a] == Status.DOWN || status[a]  == Status.JUST_PRESSED;
	}
	const bool is_just_pressed(Action a)
	{
		return status[a] == Status.JUST_PRESSED;
	}
	const bool is_just_released(Action a)
	{
		return status[a] == Status.JUST_RELEASED;
	}
	debug
	{
		const void print()
		{
			write("Input: [ ");
			foreach(Status s; status)
			{
				switch(s)
				{
					case Status.UP:
						write("u ");
						break;
					case Status.DOWN:
						write("d ");
						break;
					case Status.JUST_PRESSED:
						write("P ");
						break;
					case Status.JUST_RELEASED:
						write("R ");
						break;
					default:
						write("? ");
						break;
				}
			}
			writeln("]");
		}	
	}
}

