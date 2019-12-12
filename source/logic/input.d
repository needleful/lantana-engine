// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.input;

debug
{
	import std.stdio;
}

import gl3n.linalg;

struct Input
{
	enum Action
	{
		FORWARD,
		BACK,
		RIGHT,
		LEFT,
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
	vec2 analog_left, analog_right;
	// Relative mouse movement since last frame
	vec2 mouse_movement;
	// Status of all buttons
	Status[Action.ACTION_COUNT] status;

	void press(Action a) @nogc @safe nothrow
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

	void release(Action a) @nogc @safe nothrow
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
	void clear() @nogc @safe nothrow
	{
		analog_left = vec2(0,0);
		analog_right = vec2(0,0);
		mouse_movement = vec2(0,0);
		foreach(ref Status s; status)
		{
			s = Status.UP;
		}
	}

	const bool is_pressed(Action a) @nogc @safe nothrow
	{
		return status[a] == Status.DOWN || status[a]  == Status.JUST_PRESSED;
	}
	const bool is_just_pressed(Action a) @nogc @safe nothrow
	{
		return status[a] == Status.JUST_PRESSED;
	}
	const bool is_just_released(Action a) @nogc @safe nothrow
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

