// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.window;

import std.datetime.stopwatch: StopWatch, AutoStart;
import std.exception;
import std.format;
import std.stdio;

import bindbc.sdl;
import derelict.freetype;

import gl3n.linalg;

import lanlib.math.transform;
import lanlib.types;
import logic.input;
import render.gl;
import ui.layout: RealSize;

enum WindowState
{
	NONE,
	CLOSED,
	RESIZED,
}

/**
 * Management for SDL window.  Also manages an OpenGL 
 * context and loads libraries through Derelict
 */
struct Window
{
	Bitfield!WindowState state;
	private SDL_Window *window;
	private SDL_GLContext glContext;
	private SDL_Event event;
	private StopWatch time;

	this (int width, int height, string name)
	{
		time = StopWatch(AutoStart.yes);
		try
		{
			DerelictFT.load();
		}
		catch(derelict.util.exception.SymbolLoadException e)
		{
			// FT_Stream_OpenBzip2 is a known missing symbol
			if(e.symbolName() != "FT_Stream_OpenBzip2")
			{
				throw e;
			}
		}
		
		SDLSupport sdlresult = loadSDL();
		assert(sdlresult == sdlSupport, "Could not load SDL2");

		DerelictGL3.load();

		state.clear();

		if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0){
			throw new Exception(format("Failed to initialize SDL: %s", SDL_GetError()));
		}
		scope(failure)
		{
			SDL_Quit();
			printf("Quit SDL\n");
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
		scope(failure)
		{
			SDL_DestroyWindow(window);
			printf("Destroyed window");
		}

		glContext = SDL_GL_CreateContext(window);
		if(glContext == null)
		{
			throw new Exception(format("Failed to create OpenGL context: %s", SDL_GetError()));
		}
		scope(failure)
		{
			SDL_GL_DeleteContext(glContext);
			printf("Deleting GL context");
		}

		DerelictGL3.reload();

		if(SDL_GL_SetSwapInterval(-1) < 0)
		{
			if(SDL_GL_SetSwapInterval(1) >= 0)
			{
				debug printf("Could not create SDL_GL context with "
					~"adaptive swap interval, using synced swap interval\n");
			}
			else
			{
				debug printf("Warning: Could not enable synced swapping inverval."
					~" This could case performance issues.\n");
			}

		}

		SDL_SetRelativeMouseMode(SDL_TRUE);
		//glEnable(GL_MULTISAMPLE);

		// Our default OpenGL settings
		glEnable(GL_CULL_FACE);
		glDepthFunc(GL_LESS);
		glFrontFace(GL_CCW);
		// Frame color is irrelevant, since it should never be seen in normal execution
		glClearColor(0, 0, 0, 1);
		glClearDepth(1.0f);

		assert(glGetError() == GL_NO_ERROR);
	}

	~this()  nothrow
	{
		SDL_DestroyWindow(window);
		SDL_GL_DeleteContext(glContext);
		SDL_Quit();
	}

	void grab_mouse(bool grabbed)
	{
		SDL_SetRelativeMouseMode(grabbed? SDL_TRUE : SDL_FALSE);
	}

	void pollEvents(Input* input)  nothrow
	{
		state.clear();
		
		input.mouse_movement = vec2(0,0);

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

		while(SDL_PollEvent(&event))
		{
			switch(event.type)
			{
				case SDL_WINDOWEVENT:
					switch(event.window.event)
					{
						case SDL_WINDOWEVENT_CLOSE:
							state[WindowState.CLOSED] = true;
							break;
						case SDL_WINDOWEVENT_MAXIMIZED:
							continue;
						case SDL_WINDOWEVENT_RESIZED:
							continue;
						case SDL_WINDOWEVENT_SIZE_CHANGED:
							int w, h;
							window.SDL_GetWindowSize(&w, &h);
							glViewport(0, 0, w, h);
							state[WindowState.RESIZED] = true;
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
					input.mouse_movement = vec2(event.motion.xrel, event.motion.yrel);
					break;
				default:
					//Nothing
					break;
			}
		}

		int mouse = SDL_GetMouseState(&(input.mouse_position.x()), &(input.mouse_position.y()));
		// SDL has flipped coordinates for y-axis
		input.mouse_position.y = getSize().height - input.mouse_position.y;

		if(mouse & SDL_BUTTON_LMASK)
		{
			input.press(Input.Action.UI_INTERACT);
		}
		else if(input.is_pressed(Input.Action.UI_INTERACT))
		{
			input.release(Input.Action.UI_INTERACT);
		}
	}

	public RealSize getSize() nothrow
	{
		int w, h;
		window.SDL_GetWindowSize(&w, &h);
		return RealSize(w, h);
	}

	int[2] get_dimensions()
	{
		int w, h;
		window.SDL_GetWindowSize(&w, &h);
		return [w, h];
	}

	void begin_frame(bool clear_color = true)() 
	{
		assert(glGetError() == GL_NO_ERROR);
		static if(clear_color)
		{
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		}
		else
		{
			glClear(GL_DEPTH_BUFFER_BIT);
		}
		assert(glGetError() == GL_NO_ERROR);
	}

	void end_frame() 
	{
		SDL_GL_SwapWindow(window);
		assert(glGetError() == GL_NO_ERROR);
	}

	float delta_ms()  nothrow
	{
		float ms = time.peek.total!"usecs"/1000.0;
		time.reset();
		return ms;
	}
}