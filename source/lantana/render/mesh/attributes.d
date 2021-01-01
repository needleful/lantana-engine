// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.render.mesh.attributes;

import std.format;
import std.traits;

import lantana.file.gltf2.types;
import lantana.render.gl;
import lantana.render.material;
import lantana.render.textures;
import lantana.types : isTemplateType;

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

private int textureTypeCount(UniformT)()
	if(is(UniformT == struct))
{
	uint t = 0;
	static foreach(Type; Fields!UniformT)
	{
		static if(isTemplateType!(Texture, Type) || is(Type == TextureID))
		{
			t += 1;
		}
	}
	return t;
}

struct UniformT(Global, Instance)
	if(is(Global == struct) && is(Instance == struct))
{
	alias global = Global;
	alias instance = Instance;

	private enum gFields = FieldNameTuple!Global;
	private enum iFields = FieldNameTuple!Instance;
	private enum gFieldCount = gFields.length;

	private static uint gTextureCount = textureTypeCount!Global();
	private static uint iTextureCount = textureTypeCount!Instance();

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
		int textures_used = 0;
		glcheck();
		static foreach(i, type; Fields!Global)
		{{
			scope(failure)
			{
				import std.stdio;
				writeln("globals."~gFields[i]);
			}
			static if(is(type == TextureID))
			{
				mat.setUniform(ids[i], textures_used);
				glActiveTexture(gl_texture[textures_used++]);
				glBindTexture(GL_TEXTURE_2D, mixin("globals."~gFields[i]));
			}
			else static if(isTemplateType!(Texture, type))
			{
				mat.setUniform(ids[i], textures_used);
				glActiveTexture(gl_texture[textures_used++]);
				glBindTexture(GL_TEXTURE_2D, mixin("globals."~gFields[i]~".id"));
			}
			else
			{
				mat.setUniform!type(ids[i], mixin("globals."~gFields[i]));
			}
		}}
		assert(textures_used == gTextureCount);
		static foreach(i, type; Fields!Instance)
		{
			// Texture uniforms are set globally
			static if(is(type == TextureID) || isTemplateType!(Texture, type))
			{
				mat.setUniform(ids[gFieldCount + i], textures_used++);
			}
		}
		assert(textures_used == gTextureCount + iTextureCount);

		glcheck();
	}

	void setInstance(ref Material mat, ref Instance instance)
	{
		int textures_used = gTextureCount;
		glcheck();
		static foreach(i, type; Fields!Instance)
		{
			static if(is(type == TextureID))
			{
				glActiveTexture(gl_texture[textures_used++]);
				glBindTexture(GL_TEXTURE_2D, mixin("instance."~iFields[i]));
			}
			else static if(isTemplateType!(Texture, type))
			{
				glActiveTexture(gl_texture[textures_used++]);
				glBindTexture(GL_TEXTURE_2D, mixin("instance."~iFields[i]~".id"));
			}
			else
			{
				mat.setUniform!type(ids[gFieldCount + i], mixin("instance."~iFields[i]));
			}
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