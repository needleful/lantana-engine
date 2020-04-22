// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.input.keyboard;

import bindbc.sdl;
import lantana.types;

struct KeyboardInput
{
	BitSet!284 pressedLast;
	BitSet!284 pressed;

	char[] text;

	void press(SDL_Scancode code) nothrow @nogc
	{
		pressed[code] = true;
	}

	void release(SDL_Scancode code) nothrow @nogc
	{
		pressed[code] = false;
	}

	bool isPressed(SDL_Scancode code) nothrow @nogc
	{
		return pressed[code];
	}

	bool isJustPressed(SDL_Scancode code) nothrow @nogc
	{
		return pressed[code] && !pressedLast[code];
	}

	bool isJustReleased(SDL_Scancode code) nothrow @nogc
	{
		return !pressed[code] && pressedLast[code];
	}
}