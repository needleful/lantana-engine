// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module sys.window;

import std.exception;
import std.format;
import std.stdio;

import derelict.sdl2.sdl;

import math.transform;
import math.vector;
import sys.input;
import graphics.buffer;
import graphics.gl;
import graphics.material;

static Input.Action from_scancode(SDL_Scancode code)
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

struct Window
{
	SDL_Window *window;
	SDL_GLContext glContext;
	SDL_Event event;
	bool should_run;
	uint time;

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
		time = SDL_GetTicks();
		assert(glGetError() == GL_NO_ERROR);
	}

	~this ()
	{
		SDL_DestroyWindow(window);
		SDL_GL_DeleteContext(glContext);
		SDL_Quit();
	}

	void render_buffers(Material mat, VertexBuffer[] buffers)
	{
		mat.matId.glUseProgram();

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

	void poll_events(ref Input input)
	{
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
				default:
					//Nothing
					break;
			}
		}
	}

	void begin_frame()
	{
		// Frame color is irrelevant, since it should never be seen in normal execution
		glClearColor(0, 0, 0, 1);
		glClear(GL_COLOR_BUFFER_BIT);
		assert(glGetError() == GL_NO_ERROR);
	}

	void end_frame()
	{
		SDL_GL_SwapWindow(window);
		assert(glGetError() == GL_NO_ERROR);
	}

	@property uint delta_ms()
	{
		return SDL_GetTicks() - time;
	}
}