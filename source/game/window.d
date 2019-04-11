// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.window;

import std.exception;
import std.format;
import std.stdio;

import derelict.sdl2.sdl;

import core.types;
import graphics.buffer;
import graphics.gl;

struct Window
{
	SDL_Window *window;
	SDL_GLContext glContext;
	SDL_Event event;
	bool should_run;

	public this (int width, int height, string name)
	{
		DerelictSDL2.load();
		DerelictGL3.load();

		should_run = true;

		scope(failure)
		{
			SDL_Quit();
			printf("Exited\n");
		}

		if(SDL_Init(SDL_INIT_VIDEO) < 0){
			throw new Exception(format("Failed to initialize SDL: %s", SDL_GetError()));
		}

		assert(width > 0 && height > 0 && name.length > 0);

		window = SDL_CreateWindow(
			name.ptr, cast(int)SDL_WINDOWPOS_CENTERED, cast(int)SDL_WINDOWPOS_CENTERED, 
			width, height, SDL_WINDOW_OPENGL);

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

		assert(glGetError() == GL_NO_ERROR);
	}

	~this ()
	{
		SDL_DestroyWindow(window);
		SDL_GL_DeleteContext(glContext);
		SDL_Quit();
	}

	VertexBuffer make_buffer(Vec3[] vertices)
	{
		VertexBuffer v = VertexBuffer();
		v.id = 0;
		v.vertices = vertices;

		glGenBuffers(1, &v.id);

		glBindBuffer(GL_ARRAY_BUFFER, v.id);

		glBufferData(GL_ARRAY_BUFFER, v.bytesize, v.vertices.ptr, GL_STATIC_DRAW);

		printf("%u\n", v.bytesize);

		assert(glGetError() == GL_NO_ERROR);
		return v;
	}

	void render_buffers(VertexBuffer[] buffers)
	{
		foreach(VertexBuffer buf; buffers)
		{
			glBindBuffer(GL_ARRAY_BUFFER, buf.id);
			glEnableVertexAttribArray(0);

			glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, cast(const GLvoid*) 0);
			glDrawArrays(GL_TRIANGLES, 0, cast(uint)buf.vertices.length);

			glDisableVertexAttribArray(0);

			assert(glGetError() == GL_NO_ERROR);
		}
	}

	void poll_events()
	{
		while(SDL_PollEvent(&event))
		{
			switch(event.type)
			{
				case SDL_WINDOWEVENT:
				switch(event.window.event)
				{
					case SDL_WINDOWEVENT_CLOSE:
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

	void begin_frame()
	{
		// Frame color is irrelevant, since it should never be seen in normal execution
		glClearColor(0.5, 0.5, 1, 1);
		glClear(GL_COLOR_BUFFER_BIT);
		assert(glGetError() == GL_NO_ERROR);
	}

	void end_frame()
	{
		SDL_GL_SwapWindow(window);
		assert(glGetError() == GL_NO_ERROR);
	}
}