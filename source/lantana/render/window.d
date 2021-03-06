// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.render.window;

import std.datetime.stopwatch: StopWatch, AutoStart;
import std.exception;
import std.format;
import std.stdio;

import bindbc.sdl;
import derelict.freetype;

import gl3n.linalg;

import lantana.math.transform;
import lantana.types;
import lantana.input;
import lantana.render.gl;

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

		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

		window = SDL_CreateWindow(
			name.ptr, 
			cast(int)SDL_WINDOWPOS_CENTERED, 
			cast(int)SDL_WINDOWPOS_CENTERED, 
			width, height, 
			SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI);

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

	void grabMouse(bool grabbed)
	{
		SDL_SetRelativeMouseMode(grabbed? SDL_TRUE : SDL_FALSE);
	}

	void pollEvents(Input* input)  nothrow
	{
		state.clear();
		input.mouseMove = vec2(0);
		input.mouseWheel = ivec2(0);
		input.keyboard.pressedLast = input.keyboard.pressed;
		input.keyboard.text.length = 0;
		input.mouseLast = input.mouse;

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
							window.SDL_GL_GetDrawableSize(&w, &h);
							glViewport(0, 0, w, h);
							state[WindowState.RESIZED] = true;
							break;
						default:
							break;
					}
					break;
				case SDL_KEYDOWN:
					input.keyboard.press(event.key.keysym.scancode);
					break;
				case SDL_KEYUP:
					input.keyboard.release(event.key.keysym.scancode);
					break;
				case SDL_MOUSEMOTION:
					input.mouseMove += vec2(event.motion.xrel, -event.motion.yrel);
					break;
				case SDL_MOUSEWHEEL:
					input.mouseWheel += ivec2(event.wheel.x, -event.wheel.y);
					break;
				case SDL_TEXTINPUT:
					import std.string : fromStringz;
					input.keyboard.text ~= fromStringz(event.text.text.ptr);
					break;
				default:
					//Nothing
					break;
			}
		}

		input.mouse = SDL_GetMouseState(&(input.mousePos.x()), &(input.mousePos.y()));
		// SDL has flipped coordinates for y-axis
		input.mousePos.y = getSize().height - input.mousePos.y;
	}

	public RealSize getSize() nothrow
	{
		int w, h;
		window.SDL_GL_GetDrawableSize(&w, &h);
		return RealSize(w, h);
	}

	public vec2 getDPI() nothrow
	{
		vec2 defaultDPI;
		version(Windows)
		{
			defaultDPI = vec2(96);
		}
		else
		{
			defaultDPI = vec2(72);
		}

		float dx, dy;
		SDL_GetDisplayDPI(SDL_GetWindowDisplayIndex(window), null, &dx, &dy);

		return vec2(dx, dy);
	}

	void beginFrame(bool clear_color = true)() 
	{
		glDepthMask(GL_TRUE);
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

	void endFrame() 
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