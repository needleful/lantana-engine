// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh.attributes;

import std.traits;

import lanlib.file.gltf2.types;
import render.gl;
import render.lights;
import render.material;

struct Attr(Struct)
{
	import std.format;

	enum fields = FieldNameTuple!Struct;
	AttribId[fields.length] ids;

	this(ref Material mat)
	{
		static foreach(i, field; fields)
		{
			ids[i] = mat.getAttribId(field);
		}
	}

	void enable()
	{
		foreach(id; ids)
		{
			glEnableVertexAttribArray(id);
		}
	}

	void disable()
	{
		foreach(id; ids)
		{
			glDisableVertexAttribArray(id);
		}
	}

	void initialize(Buffer)(Buffer bufferViews)
	{
		static foreach(i, Type; Fields!Struct)
		{
			static if(isIntegral!Type)
			{
				glVertexAttribIPointer(
					ids[i],
					mixin("bufferViews."~fields[i]).dataType.componentCount,
					mixin("bufferViews."~fields[i]).componentType,
					0,
					cast(void*) mixin("bufferViews."~fields[i]).byteOffset);
			}
			else
			{
				glVertexAttribPointer(
					ids[i],
					mixin("bufferViews."~fields[i]).dataType.componentCount,
					mixin("bufferViews."~fields[i]).componentType,
					GL_FALSE,
					0,
					cast(void*) mixin("bufferViews."~fields[i]).byteOffset);
			}
		}
	}

	static foreach(i, field; fields)
	{
		mixin(format("AttribId %s() const nothrow {return ids[%d];}", field, i));
	}
}

enum animated;

struct MeshSpec(Attributes, Loader)
{
	alias attribType = Attr!Attributes;
	alias loader = Loader;
	enum isAnimated = hasUDA!(Attributes, animated);
}
