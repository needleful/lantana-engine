// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.sys.sdl;

import std.exception;
import std.format;
import std.stdio;

import derelict.sdl2.sdl;

import lanlib.math.transform;
import lanlib.math.vector;
import lanlib.sys.input;
import lanlib.sys.gl;

static Input.Action from_scancode(SDL_Scancode code) @nogc @safe nothrow
{
	if(code == SDL_SCANCODE_UP || code == SDL_SCANCODE_W)
	{
		return Input.Action.UP;
	}
	else if(code == SDL_SCANCODE_DOWN || code == SDL_SCANCODE_S)
	{
		return Input.Action.DOWN;
	}
	else if(code == SDL_SCANCODE_LEFT || code == SDL_SCANCODE_A)
	{
		return Input.Action.LEFT;
	}
	else if(code == SDL_SCANCODE_RIGHT || code == SDL_SCANCODE_D)
	{
		return Input.Action.RIGHT;
	}
	else if(code == SDL_SCANCODE_SPACE)
	{
		return Input.Action.JUMP;
	}
	else if(code == SDL_SCANCODE_ESCAPE)
	{
		return Input.Action.PAUSE;
	}
	else
	{
		return Input.Action.UNKNOWN;
	}
}

enum WindowState : ubyte
{
	NONE = 0,
	CLOSED = 1,
	RESIZED = 2,

}

struct SDLWindow
{
	SDL_Window *window;
	SDL_GLContext glContext;
	SDL_Event event;
	WindowState state;
	uint time;

	this (int width, int height, string name)
	{
		DerelictSDL2.load();
		DerelictGL3.load();

		state = WindowState.NONE;

		scope(failure)
		{
			SDL_Quit();
			printf("Exited\n");
		}

		if(SDL_Init(SDL_INIT_VIDEO) < 0){
			throw new Exception(format("Failed to initialize SDL: %s", SDL_GetError()));
		}

		assert(width > 0 && height > 0 && name.length > 0);

		SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
		SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

		window = SDL_CreateWindow(
			name.ptr, cast(int)SDL_WINDOWPOS_CENTERED, cast(int)SDL_WINDOWPOS_CENTERED, 
			width, height, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);

		if(window == null)
		{
			throw new Exception(format("Failed to create window: %s", SDL_GetError()));
		}

		glContext = SDL_GL_CreateContext(window);
		if(glContext == null)
		{
			throw new Exception(format("Failed to create OpenGL context: %s", SDL_GetError()));
		}
		DerelictGL3.reload();

		if(SDL_GL_SetSwapInterval(-1) < 0)
		{
			if(SDL_GL_SetSwapInterval(1) < 0)
			{
				throw new Exception(format("Failed to create OpenGL context: %s", SDL_GetError()));
			}
		}

		SDL_SetRelativeMouseMode(SDL_TRUE);
		glEnable(GL_MULTISAMPLE);

		// Our default OpenGL settings
		glEnable(GL_CULL_FACE);
		glEnable(GL_DEPTH_TEST);
		glDepthFunc(GL_LESS);
		glFrontFace(GL_CW);
		// Frame color is irrelevant, since it should never be seen in normal execution
		glClearColor(0, 0, 0, 1);
		glClearDepth(1.0f);

		time = SDL_GetTicks();
		assert(glGetError() == GL_NO_ERROR);
	}

	~this () @nogc nothrow
	{
		SDL_DestroyWindow(window);
		SDL_GL_DeleteContext(glContext);
		SDL_Quit();
	}

	void grab_mouse(bool grabbed)
	{
		SDL_SetRelativeMouseMode(grabbed? SDL_TRUE : SDL_FALSE);
	}

	void poll_events(ref Input input) @nogc nothrow
	{
		input.mouse_movement = Vec2(0,0);
		foreach(ref Input.Status status; input.status)
		{
			if(status == Input.Status.JUST_RELEASED)
			{
				status = Input.Status.UP;
			}
			if(status == Input.Status.JUST_PRESSED)
			{
				status = Input.Status.DOWN;
			}
		}

		time = SDL_GetTicks();
		state = WindowState.NONE;
		while(SDL_PollEvent(&event))
		{
			switch(event.type)
			{
				case SDL_WINDOWEVENT:
					switch(event.window.event)
					{
						case SDL_WINDOWEVENT_CLOSE:
							state |= WindowState.CLOSED;
							break;
						case SDL_WINDOWEVENT_MAXIMIZED:
							continue;
						case SDL_WINDOWEVENT_RESIZED:
							continue;
						case SDL_WINDOWEVENT_SIZE_CHANGED:
							int w, h;
							window.SDL_GetWindowSize(&w, &h);
							glViewport(0, 0, w, h);
							state |= WindowState.RESIZED;
							break;
						default:
							break;
					}
					break;
				case SDL_KEYDOWN:
					Input.Action a = from_scancode(event.key.keysym.scancode);
					if(a != Input.Action.UNKNOWN)
					{
						input.press(a);
					}
					break;
				case SDL_KEYUP:
					Input.Action a = from_scancode(event.key.keysym.scancode);
					if(a != Input.Action.UNKNOWN)
					{
						input.release(a);
					}
					break;
				case SDL_MOUSEMOTION:
					input.mouse_movement = Vec2(event.motion.xrel, event.motion.yrel);
					break;
				default:
					//Nothing
					break;
			}
		}
	}

	int[2] get_dimensions()
	{
		int w, h;
		window.SDL_GetWindowSize(&w, &h);
		return [w, h];
	}

	void begin_frame() @nogc
	{
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		assert(glGetError() == GL_NO_ERROR);
	}

	void end_frame() @nogc
	{
		SDL_GL_SwapWindow(window);
		assert(glGetError() == GL_NO_ERROR);
	}

	@property uint delta_ms() @nogc nothrow
	{
		return SDL_GetTicks() - time;
	}
}