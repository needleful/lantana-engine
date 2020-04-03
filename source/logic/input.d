// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.input;

debug import std.stdio;

import bindbc.sdl;
import gl3n.linalg;

import lanlib.types;
import logic.keyboard;

struct Input
{
	enum Mouse
	{
		Left,
		Right,
		Middle
	}

	KeyboardInput keyboard;
	// Relative mouse movement since last frame
	vec2 mouseMove;
	// Absolute position of the mouse
	ivec2 mousePos, mouseWheel;

	uint mouse, mouseLast;

	this(ref Input rhs)
	{
		keyboard = rhs.keyboard;
		mouseMove = rhs.mouseMove;
		mousePos = rhs.mousePos;
		mouse = rhs.mouse;
		mouseLast = rhs.mouseLast;
		mouseWheel = rhs.mouseWheel;
	}

	this(Input* rhs)
	{
		keyboard = rhs.keyboard;
		mouseMove = rhs.mouseMove;
		mousePos = rhs.mousePos;
		mouse = rhs.mouse;
		mouseLast = rhs.mouseLast;
		mouseWheel = rhs.mouseWheel;
	}

	void apply(ref Input rhs)
	{
		keyboard = rhs.keyboard;
		mouseMove = rhs.mouseMove;
		mousePos = rhs.mousePos;
		mouse = rhs.mouse;
		mouseLast = rhs.mouseLast;
		mouseWheel = rhs.mouseWheel;
	}

	// Reset input, for example when re-entering the window
	void clear() @safe nothrow
	{
		mouseMove = vec2(0,0);
		mouseWheel = ivec2(0,0);
		keyboard.pressed.clearAll();
		keyboard.text.length = 0;
		mouse = 0;
	}

	bool isClicked(Mouse p_button)
	{
		switch(p_button)
		{
			case Mouse.Left:
				return (mouse & SDL_BUTTON_LMASK) != 0;
			case Mouse.Right:
				return (mouse & SDL_BUTTON_RMASK) != 0;
			case Mouse.Middle:
				return (mouse & SDL_BUTTON_MMASK) != 0;
			default:
				return false;
		}
	}

	bool isJustClicked(Mouse p_button)
	{
		ubyte flag = 0;
		switch(p_button)
		{
			case Mouse.Left:
				flag = SDL_BUTTON_LMASK;
				break;
			case Mouse.Right:
				flag = SDL_BUTTON_RMASK;
				break;
			case Mouse.Middle:
				flag = SDL_BUTTON_MMASK;
				break;
			default:
				return false;
		}
		return ((mouse & flag) != 0) && ((mouseLast & flag) == 0);
	}

	bool isJustReleased(Mouse p_button)
	{
		ubyte flag = 0;
		switch(p_button)
		{
			case Mouse.Left:
				flag = SDL_BUTTON_LMASK;
				break;
			case Mouse.Right:
				flag = SDL_BUTTON_RMASK;
				break;
			case Mouse.Middle:
				flag = SDL_BUTTON_MMASK;
				break;
			default:
				return false;
		}
		return ((mouse & flag) == 0) && ((mouseLast & flag) != 0);
	}
}