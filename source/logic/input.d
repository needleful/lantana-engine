// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.input;

debug import std.stdio;

import bindbc.sdl;
import gl3n.linalg;

import lanlib.types: ivec2;

struct Input
{
	enum Action
	{
		FORWARD,
		BACK,
		RIGHT,
		LEFT,
		PAUSE,
		GAME_INTERACT,
		UI_INTERACT,
		DEBUG1,
		DEBUG2,
		DEBUG3,
		DEBUG4,
		DEBUG5,
		UNKNOWN,
		ACTION_COUNT,
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
	// Absolute position of the mouse
	ivec2 mouse_position;
	// Status of all buttons
	Status[Action.ACTION_COUNT] status;

	void press(Action a)  @safe nothrow
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

	void release(Action a)  @safe nothrow
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
	void clear()  @safe nothrow
	{
		analog_left = vec2(0,0);
		analog_right = vec2(0,0);
		mouse_movement = vec2(0,0);
		foreach(ref Status s; status)
		{
			s = Status.UP;
		}
	}

	const bool is_pressed(Action a)  @safe nothrow
	{
		return status[a] == Status.DOWN || status[a]  == Status.JUST_PRESSED;
	}
	const bool is_just_pressed(Action a)  @safe nothrow
	{
		return status[a] == Status.JUST_PRESSED;
	}
	const bool is_just_released(Action a)  @safe nothrow
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

static Input.Action from_scancode(SDL_Scancode code)  @safe nothrow
{
	if(code == SDL_SCANCODE_UP || code == SDL_SCANCODE_W)
	{
		return Input.Action.FORWARD;
	}
	else if(code == SDL_SCANCODE_DOWN || code == SDL_SCANCODE_S)
	{
		return Input.Action.BACK;
	}
	else if(code == SDL_SCANCODE_LEFT || code == SDL_SCANCODE_A)
	{
		return Input.Action.LEFT;
	}
	else if(code == SDL_SCANCODE_RIGHT || code == SDL_SCANCODE_D)
	{
		return Input.Action.RIGHT;
	}
	else if(code == SDL_SCANCODE_RETURN || code == SDL_SCANCODE_E)
	{
		return Input.Action.GAME_INTERACT;
	}
	else if(code == SDL_SCANCODE_ESCAPE)
	{
		return Input.Action.PAUSE;
	}
	else if(code == SDL_SCANCODE_F1)
	{
		return Input.Action.DEBUG1;
	}
	else if(code == SDL_SCANCODE_F2)
	{
		return Input.Action.DEBUG2;
	}
	else if(code == SDL_SCANCODE_F3)
	{
		return Input.Action.DEBUG3;
	}
	else if(code == SDL_SCANCODE_F4)
	{
		return Input.Action.DEBUG4;
	}
	else if(code == SDL_SCANCODE_F5)
	{
		return Input.Action.DEBUG5;
	}
	else
	{
		return Input.Action.UNKNOWN;
	}
}