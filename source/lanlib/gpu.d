// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.gpu;

import lanlib.types;

/// Testing

import std.format;
import std.stdio;

/// FreeList objects implement a constructor, update() and clean()
@FreeListCompatible
struct Texture
{
	uint id;
	private uint internalID;

	this(uint p_id)
	{
		id = p_id;
		internalID = p_id;
		writefln("Creating texture %u[%u]", id, internalID);
	}

	/// Update should have the same parameters as the constructor
	void update(uint p_id)
	{
		id = p_id;
		writefln("Updating texture %u[%u]", id, internalID);
	}

	void clean()
	{
		writefln("Destroying texture %u[%u]", id, internalID);
		id = 0;
	}
}

void testGpuManager()
{

	auto bits = BitSet!450();
	bits.setAll();
	assert(bits.firstSetBit() == 0);
	bits.clearAll();
	assert(bits.firstSetBit() == -1);

	foreach(uint i; 0..bits.size)
	{
		bits[i] = (i%3) == 0;
		assert(bits[i] == ((i%3) == 0), "assignment failed: ");
	}

	for(long i = bits.firstSetBit(); i != -1; i = bits.nextSetBit(i))
	{
		assert((i % 3) == 0, format("%d", i));
	}

	bits.clearAll();
	bits[221] = true;
	bits[300] = true;
	bits[301] = true;

	assert(bits[221] == true);
	assert(bits[300] == true);
	assert(bits[301] == true);

	assert(bits.firstSetBit() == 221, format("%d", bits.firstSetBit()));
	assert(bits.nextSetBit(221) == 300, format("%d", bits.nextSetBit(221)));
	assert(bits.nextSetBit(300) == 301, format("%d", bits.nextSetBit(300)));
	assert(bits.nextSetBit(301) == -1, format("%d", bits.nextSetBit(301)));

	auto textures = new FreeList!(Texture, 128)();

	foreach(uint i; 0..64)
	{
		FLRef texRef = textures.getOrCreate(i);
		assert(texRef != FLRef.invalid);
	}

	for(uint i = 0; i < 64; i+= 2)
	{
		textures.release(FLRef(i));
	}

	foreach(i; 0..24)
	{
		FLRef texRef = textures.getOrCreate(i);
		assert(texRef != FLRef.invalid);
	}

	assert(textures.clean() == 8);
}