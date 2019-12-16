// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.images;

import core.stdc.stdio;
import std.math;

import deimos.freeimage;

import gl3n.linalg;
import lanlib.util.gl;

alias ivec2 = Vector!(int, 2);

public struct Mesh2D
{
	GLuint pos;
	GLuint uv;
	GLuint ebo;
	GLuint vao;

	ivec2[] vertices;
	vec2[] UVs;
	uint[] triangles;

	public this(ivec2[] verts, vec2[] UVs, uint[] elements) @nogc
	{

		assert(verts.length == UVs.length);
		this.vertices = verts;
		this.triangles = elements;
		this.UVs = UVs;

		glcheck();

		glGenBuffers(1, &pos);
		glBindBuffer(GL_ARRAY_BUFFER, pos);
		glBufferData(GL_ARRAY_BUFFER, vertsize, vertices.ptr, GL_STATIC_DRAW);

		glcheck();

		glGenBuffers(1, &uv);
		glBindBuffer(GL_ARRAY_BUFFER, uv);
		glBufferData(GL_ARRAY_BUFFER, vertsize, UVs.ptr, GL_STATIC_DRAW);

		glcheck();

		glGenBuffers(1, &ebo);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, trisize, triangles.ptr, GL_STATIC_DRAW);

		glcheck();
	}

	~this() @nogc nothrow
	{
		glDeleteBuffers(1, &pos);
		glDeleteBuffers(1, &uv);
		glDeleteBuffers(1, &ebo);
	}

	@property public const ulong vertsize() @safe @nogc nothrow
	{
		return vertices.length*vec2.sizeof;
	}

	@property public const ulong trisize() @safe @nogc nothrow
	{
		return triangles.length*uint.sizeof;
	}
}

public struct Texture
{
	FIBITMAP *bitmap;
	GLuint id;

	@disable this();

	this(string filename) @nogc
	{
		auto format = FreeImage_GetFileType(filename.ptr);
		bitmap = FreeImage_Load(format, filename.ptr);

		glcheck();

		if(!bitmap)
		{
			printf("Failed to load image: %d\n", filename.ptr);
		}

		glGenTextures(1, &id);

		glBindTexture(GL_TEXTURE_2D, id);

		glTexImage2D (GL_TEXTURE_2D,
				0, GL_RGB,
				width(), height(),
				0, GL_RGB,
				GL_UNSIGNED_BYTE, data());

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

		glcheck();
	}

	~this() @nogc nothrow
	{
		glDeleteTextures(1, &id);
		FreeImage_Unload(bitmap);
	}

	uint width() @nogc nothrow
	{
		return FreeImage_GetWidth(bitmap);
	}

	uint height() @nogc nothrow
	{
		return FreeImage_GetHeight(bitmap);
	}

	ubyte* data() @nogc nothrow
	{
		return FreeImage_GetBits(bitmap);
	}
}