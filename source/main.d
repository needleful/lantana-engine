// Lantana
// main.d
// Licensed under GPL v3.0

/// The main module for running the game
module lantana.main;

// TODO: render animated sprite

import derelict.sdl2.sdl;

import lantana.core.app;
import lantana.core.enums: Result;
import lantana.render.gl;
import lantana.render.shaders;


MApplication app;

int main()
{
	Result r = app.init("Lantana 0.0.1");
	scope(exit) app.cleanup();

	if(r == Result.Failure)
	{
		return 1;
	}
	return run();
}

/// The main method of the game,
/// everything that can be made nogc should be here
int run() @nogc
{

	import std.stdio;
	// Initialize renderer
	GLuint pixelProgram;
	{
		GLuint[2] shaders = 
		[
			MakeShader(GL_VERTEX_SHADER, &pixelShaderVert_source[0]),
			MakeShader(GL_FRAGMENT_SHADER, &pixelShaderFrag_source[0])
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
		pixelProgram = LinkShaders(shaders);
		if(pixelProgram == 0)
		{
			puts("Failed to link text shader program");
			return -1;
		}
	}
	scope(exit) glDeleteProgram(pixelProgram);

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
		glGenVertexArrays(1, &vao_text);
		glBindVertexArray(vao_text);

		glGenBuffers(1, &vbo_pos);
		glGenBuffers(1, &vbo_uv);
		glGenBuffers(1, &ebo_text);

		glBindBuffer(GL_ARRAY_BUFFER, vbo_pos);
		glBufferData(GL_ARRAY_BUFFER, int.sizeof*2*quad.length, quad.ptr, GL_STATIC_DRAW);
		glEnableVertexAttribArray(0);
		glVertexAttribIPointer(0, 2, GL_INT, 0, cast(const(GLvoid*)) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo_uv);
		glBufferData(GL_ARRAY_BUFFER, float.sizeof*2*uv.length, uv.ptr, GL_STATIC_DRAW);
		glEnableVertexAttribArray(1);
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, cast(const(GLvoid*)) 0);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo_text);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, uint.sizeof*elements.length, elements.ptr, GL_STATIC_DRAW);

		glBindVertexArray(0);
	}
	scope(exit)
	{
		glDeleteBuffers(1, &vbo_pos);
		glDeleteBuffers(1, &vbo_uv);
		glDeleteVertexArrays(1, &vao_text);
	}

	GLuint tx_sprite;
	{
		glGenTextures(1, &tx_sprite);
	}
	
	// Render text

	uint[2] screen_size = [512, 512];
	int[2] translate = [0,0];
	float[4] color = [1, 1, 1, 1];

	glClearColor(0.8, 0.3, 0.0, 1.0);

	auto uTranslate = glGetUniformLocation(pixelProgram, "translation");
	auto uScreen = glGetUniformLocation(pixelProgram, "screen_size");
	auto uColor = glGetUniformLocation(pixelProgram, "color");
	auto uSprite = glGetUniformLocation(pixelProgram, "sprite");

	debug
	{
		assert(uTranslate >= 0);
		assert(uScreen >= 0);
		assert(uColor >= 0);
		assert(uSprite >= 0);
	}

	glUseProgram(pixelProgram);
	{
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, tx_sprite);

		glUniform2iv(uTranslate, 1, &translate[0]);
		glUniform2uiv(uScreen, 1, &screen_size[0]);
		glUniform4fv(uColor, 1, &color[0]);
		glUniform1i(uSprite, 0);

		glBindVertexArray(vao_text);
		glDrawElements(GL_TRIANGLES, elements.length, GL_UNSIGNED_INT, cast(GLvoid*) 0);
		glBindVertexArray(0);
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