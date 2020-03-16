// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.mesh.attributes;

import std.format;
import std.traits;

import lanlib.file.gltf2.types;
import render.gl;
import render.lights;
import render.material;

struct Attr(Struct)
{

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
	alias accessor = GLBAccessor!Attributes;
	alias loader = Loader;
	enum isAnimated = hasUDA!(Attributes, animated);
}

struct UniformT(Global, Instance)
	if(is(Global == struct) && is(Instance == struct))
{
	alias global = Global;
	alias instance = Instance;

	private enum gFields = FieldNameTuple!Global;
	private enum iFields = FieldNameTuple!Instance;
	private enum gFieldCount = gFields.length;

	UniformId[gFields.length + iFields.length] ids;

	this(ref Material mat)
	{
		static foreach(i, field; gFields)
		{
			ids[i] = mat.getUniformId(field);
		}

		static foreach(i, field; iFields)
		{
			ids[gFieldCount + i] = mat.getUniformId(field);
		}
	}

	void setGlobals(ref Material mat, ref Global globals)
	{
		glcheck();
		static foreach(i, type; Fields!Global)
		{
			mat.setUniform!type(ids[i], mixin("globals."~gFields[i]));
		}
		glcheck();
	}

	void setInstance(ref Material mat, ref Instance instance)
	{
		glcheck();
		static foreach(i, type; Fields!Instance)
		{
			mat.setUniform!type(ids[gFieldCount + i], mixin("instance."~iFields[i]));
		}
		glcheck();
	}

	static foreach(i, field; gFields)
	{
		mixin(format("UniformId g_%s() {return ids[%d];}", field, i));
	}
	static foreach(i, field; iFields)
	{
		mixin(format("UniformId i_%s() {return ids[%d];}", field, i+gFieldCount));
	}
}