// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.render.mesh.attributes;

import std.format;
import std.traits;

import lantana.file.gltf2.types;
import lantana.math.transform;
import lantana.render;

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
			glcheck();
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

	void setUniforms(Uniforms)(ref Material mat, ref Uniforms uniforms)
		if(is(Uniforms == Global) || is(Uniforms == Instance))
	{
		enum isGlobal = is(Uniforms == Global);
		static if (isGlobal) {
			alias fieldTuple = gFields;
		}
		else {
			alias fieldTuple = iFields;
		}

		import lantana.types.core: isTemplateType;
		glcheck();

		int texId = 0;

		static foreach(i, Type; Fields!Uniforms)
		{{
			UniformId id = ids[isGlobal? i : i+gFieldCount];

			static if (isTemplateType!(Texture, Type)) {
				mat.setUniform(id, texId);
				glActiveTexture(GL_TEXTURE0 + texId);
				glBindTexture(GL_TEXTURE_2D, mixin("uniforms."~fieldTuple[i]~".id"));
				texId ++;
			}
			else static if(is(Type == Transform)) {
			 	mixin("uniforms."~fieldTuple[i]~".computeMatrix();");
				mat.setUniform(id,  mixin("uniforms."~fieldTuple[i]~".matrix"));
			}
			else {
				mat.setUniform(id, mixin("uniforms."~fieldTuple[i]));
			}
			glcheck();
		}}
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