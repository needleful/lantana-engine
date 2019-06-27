// Lantana
// main.d
// Licensed under GPL v3.0

/// The main module for running the game
module lantana.main;

import derelict.freetype;
import derelict.sdl2.sdl;

import lantana.gl;
import lantana.shaders;

import std.stdio;

struct Application
{
	SDL_Window* window;
	SDL_GLContext gl;
}

Application app;

int main()
{
	// Initialize Application
	DerelictSDL2.load();
	DerelictGL3.load();
	DerelictFT.load();

	if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) != 0)
	{
		printf("Failed to initialize SDL: %s\n", SDL_GetError());
		return 1;
	}
	scope(exit)
	{
		SDL_Quit();
		puts("SDL terminated");
	}

	app.window = SDL_CreateWindow(
		"Lantana 0.0.0", 
		SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
		512, 512, SDL_WINDOW_OPENGL);

	if(app.window == null)
	{
		printf("Failed to open SDL window: %s\n", SDL_GetError());
		return 2;
	}
	scope(exit) 
	{
		SDL_DestroyWindow(app.window);
		puts("Window destroyed");
	}

	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

	app.gl = SDL_GL_CreateContext(app.window);
	scope(exit)
	{
		SDL_GL_DeleteContext(app.gl);
		puts("Deleted OpenGL context");
	}

	SDL_GL_MakeCurrent(app.window, app.gl);

	auto loadedVersion = DerelictGL3.reload();
	if(loadedVersion < GLVersion.gl40)
	{
		printf("Failed to load OpenGL 4.0: %s\n", SDL_GetError());
		return 3;
	}
	
	return run();
}

/// The main method of the game,
/// everything that can be made nogc should be here
int run() @nogc
{
	// Initialize renderer
	GLuint textProgram;
	{
		GLuint[2] shaders = 
		[
			MakeShader(GL_VERTEX_SHADER, &textShaderVert_source[0]),
			MakeShader(GL_FRAGMENT_SHADER, &textShaderFrag_source[0])
		];

		if(shaders[0] == 0)
		{
			puts("Failed to load required vertex shader");
			return -1;
		}

		if(shaders[1] == 0)
		{
			puts("Failed to load required fragment shader");
			return -1;
		}
		textProgram = LinkShaders(shaders);
		if(textProgram == 0)
		{
			puts("Failed to link text shader program");
			return -1;
		}
		glCheck();
	}
	scope(exit) glDeleteProgram(textProgram);

	
	//Initialize text system

	import core.stdc.stdlib;
	GLuint texture_glyphs;
	ubyte* glyph_atlas;
	{
		glyph_atlas = cast(ubyte*) malloc(ubyte.sizeof*512*512);
		// REMOVE: Generating debug value
		import std.math;
		foreach(x; 0..512)
		{
			foreach(y; 0..512)
			{
				glyph_atlas[x*512+y] = 1;
			}
		}

		if(glyph_atlas == null)
		{
			puts("Failed to allocate test texture");
			return -4;
		}
		glGenTextures(1, &texture_glyphs);
		glBindTexture(GL_TEXTURE_2D, texture_glyphs);
		glTexImage2D(
			GL_TEXTURE_2D, 0, 
			GL_R8, 512, 512, 0,
			GL_RED, GL_UNSIGNED_BYTE, 
			glyph_atlas);

		glCheck();
	}
	scope(exit) free(glyph_atlas);


	int[2][4] quad = 
	[
		[20, 492],
		[492, 492],
		[492, 20],
		[20, 20]
	];

	float[2][4] uv = 
	[
		[0, 1],
		[1, 1],
		[1, 0],
		[0, 0]
	];

	uint[6] elements =
	[
		0, 1, 2,
		0, 2, 3
	];

	GLuint vao_text, ebo_text, vbo_pos, vbo_uv;
	{
		glCheck();
		glGenVertexArrays(1, &vao_text);
		glBindVertexArray(vao_text);

		glCheck();
		glGenBuffers(1, &vbo_pos);
		glGenBuffers(1, &vbo_uv);
		glGenBuffers(1, &ebo_text);

		glCheck();
		glBindBuffer(GL_ARRAY_BUFFER, vbo_pos);
		glBufferData(GL_ARRAY_BUFFER, int.sizeof*2*quad.length, &quad[0][0], GL_STATIC_DRAW);
		glEnableVertexAttribArray(0);
		glVertexAttribIPointer(0, 2, GL_INT, 0, cast(const(GLvoid*)) 0);

		glCheck();
		glBindBuffer(GL_ARRAY_BUFFER, vbo_uv);
		glBufferData(GL_ARRAY_BUFFER, float.sizeof*2*uv.length, &uv[0][0], GL_STATIC_DRAW);
		glEnableVertexAttribArray(1);
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, cast(const(GLvoid*)) 0);

		glCheck();
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo_text);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, uint.sizeof*elements.length, &elements[0], GL_STATIC_DRAW);

		glBindVertexArray(0);

		glCheck();
	}
	scope(exit)
	{
		glDeleteBuffers(1, &vbo_pos);
		glDeleteBuffers(1, &vbo_uv);
		glDeleteVertexArrays(1, &vao_text);

		glCheck();
	}
	
	// Render text

	glEnable(GL_CULL_FACE);
	glFrontFace(GL_CW);

	uint[2] screen_size = [512, 512];
	int[2] translate = [0,0];
	float[4] color = [1, 1, 1, 1];

	glClearColor(0.1, 0.0, 0.2, 1.0);
	string text = "Hello world!";

	auto uTranslate = glGetUniformLocation(textProgram, "translation");
	auto uScreen = glGetUniformLocation(textProgram, "screen_size");
	auto uColor = glGetUniformLocation(textProgram, "color");
	auto uAlphaTex = glGetUniformLocation(textProgram, "alpha");
	glCheck();

	debug
	{
		assert(uTranslate >= 0);
		assert(uScreen >= 0);
		assert(uColor >= 0);
		assert(uAlphaTex >= 0);
	}

	glUseProgram(textProgram);
	{
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, texture_glyphs);
		glCheck();

		glUniform2iv(uTranslate, 1, &translate[0]);
		glCheck();
		glUniform2uiv(uScreen, 1, &screen_size[0]);
		glCheck();
		glUniform4fv(uColor, 1, &color[0]);
		glCheck();
		glUniform1i(uAlphaTex, 0);
		glCheck();

		glBindVertexArray(vao_text);
		glDrawElements(GL_TRIANGLES, elements.length, GL_UNSIGNED_INT, cast(GLvoid*) 0);
		glBindVertexArray(0);
		glCheck();
	}
	SDL_GL_SwapWindow(app.window);

	SDL_Event event;
	bool should_quit = false;
	while(!should_quit)
	{
		while(SDL_PollEvent(&event))
		{
			switch(event.type)
			{
			case SDL_WINDOWEVENT:
				switch(event.window.event)
				{
				case SDL_WINDOWEVENT_CLOSE:
					should_quit = true;
					break;
				default:
					break;
				}
				break;
			default: break;
			}
		}
	}

	return 0;
}