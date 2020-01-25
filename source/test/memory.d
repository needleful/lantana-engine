// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module test.memory;

import std.stdio;
import lanlib.util.memory;

// Interesting discovery:
// Lists don't destroy their members upon destruction, presumably leaving it to the GC.
// If we want, we can automatically call destructors on data in non-GC memory
// by wrapping it in a struct that does something like this.
struct AllocList(Type)
{
	Type[] data;

	this(Type[] p_data){
		data = p_data;
	}

	~this()
	{
		foreach(ref Type t; data)
		{
			destroy(t);
		}
	}
}

struct Texture
{
	ubyte[] data;
	int id;

	this(ubyte[] p_data, int p_id)
	{
		data = p_data;
		id = p_id;
	}

	~this()
	{
		writefln("Destroying texture %d", id);
	}
}

struct Mesh
{
	float[] vertices;
	ushort[] elements;
	int id;

	this(float[] p_verts, ushort[] p_elem, int p_id)
	{
		vertices = p_verts;
		elements = p_elem;
		id = p_id;
	}

	~this()
	{
		writefln("Destroying mesh %d", id);
	}
}

struct Light
{
	int id;

	this(int p_id)
	{
		id = p_id;
	}

	~this()
	{
		writefln("Destroying light %d", id);
	}
}

struct Level
{
	AllocList!Texture textures;
	AllocList!Mesh meshes;
	AllocList!Light lights;

	this(Texture[] p_textures, Mesh[] p_meshes, Light[] p_lights)
	{
		textures = p_textures;
		meshes = p_meshes;
		lights = p_lights;
	}

	~this()
	{
		writeln("Destroying level");
	}
}

int testMemory()
{
	writeln("Beginning memory test");
	BaseRegion mm = BaseRegion(4096);

	ubyte[] bytes1 = mm.testData!ubyte(27);
	ubyte[] bytes2 = mm.testData!ubyte(48);

	Texture[] textures = mm.makeList!Texture(3);
	textures[0].id = 0;
	textures[0].data = bytes1;
	textures[1].id = 1;
	textures[1].data = bytes2;
	textures[2].id = 2;
	textures[2].data = bytes1;

	float[] verts1 = mm.testData!float(89);
	ushort[] elems1 = mm.testData!ushort(69);
	float[] verts2 = mm.testData!float(102);
	ushort[] elems2 = mm.testData!ushort(180);

	Mesh[] meshes = mm.makeList!Mesh(2);
	meshes[0].id = 0;
	meshes[1].id = 1;
	meshes[0].elements = elems1;
	meshes[1].elements = elems2;
	meshes[0].vertices = verts1;
	meshes[1].vertices = verts2;

	Light[] lights = cast(Light[]) mm.testData!int(30);

	Level lvl = Level(textures, meshes, lights);

	foreach(ref Mesh m; lvl.meshes.data)
	{
		writef("Mesh %d: ", m.id);
		writef(" @[%X]", m.vertices.ptr);
		foreach(float f; m.vertices)
		{
			writef(" %f", f);
		}
		writeln();
	}

	return 0;
}

Type[] testData(Type)(ref Region p_alloc, uint p_length)
{
	Type[] data = p_alloc.makeList!Type(p_length);
	foreach(int i; 0..p_length)
	{
		data[i] = cast(Type) i;
	}
	return data;
}