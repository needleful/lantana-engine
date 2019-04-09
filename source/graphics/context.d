// Part of the Daisy Engine
// developed by needleful
// Licensed under GPL v3.0

module graphics.context;

import std.stdio;

import derelict.sdl2.sdl;
import derelict.opengl;
mixin glFreeFuncs!(GLVersion.gl33);

import core.types;
import graphics.buffer;

struct GContext
{
	SDL_Window *window;
	SDL_GLContext glContext;
	SDL_Event event;
	bool should_run;

	bool init(int width, int height, const char* name)
	{
		DerelictSDL2.load();
		DerelictGL3.load();

		if(SDL_Init(SDL_INIT_VIDEO) < 0){
			printf("Failed to initialize SDL: %s\n", SDL_GetError());
			return false;
		}
		window = SDL_CreateWindow(
			name, cast(int)SDL_WINDOWPOS_CENTERED, cast(int)SDL_WINDOWPOS_CENTERED, 
			width, height, SDL_WINDOW_OPENGL);

		if(window == null)
		{
			printf("Failed to create window: %s\n", SDL_GetError());
			return false;
		}

		glContext = SDL_GL_CreateContext(window);
		if(glContext == null)
		{
			printf("Failed to create OpenGL context: %s\n", SDL_GetError());
			return false;
		}
		should_run = true;
		return true;
	}

	VertexBuffer make_buffer(Vec3[] vertices)
	{
		VertexBuffer v;
		v.vertices = vertices;
		glGenBuffers(1, &v.id);
		glBindBuffer(GL_ARRAY_BUFFER, v.id);
		glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, vertices.ptr, GL_STATIC_DRAW);

		return v;
	}

	void begin_frame()
	{
		// Frame color is irrelevant, since it should never be seen in normal execution
		glClearColor(0.5, 0.5, 1, 1);
		glClear(GL_COLOR_BUFFER_BIT);
	}

	void poll_events()
	{
		while(SDL_PollEvent(&event))
		{
			switch(event.type)
			{
				case SDL_WINDOWEVENT:
				switch(cast(int)event.window.type)
				{
					case cast(int)SDL_WINDOWEVENT_CLOSE:
						should_run = false;
						break;
					default:
						//Nothing
						break;

				}
				break;
				default:
					//Nothing
					break;
			}
		}
	}

	void end_frame()
	{
		SDL_GL_SwapWindow(window);
	}

	void cleanup()
	{
		if(window != null)
		{
			SDL_DestroyWindow(window);
		}
		if(glContext != null)
		{
			SDL_GL_DeleteContext(glContext);
		}
		SDL_Quit();
	}
}