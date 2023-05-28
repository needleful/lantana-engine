// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.file.gltf2.types;

import std.file;
debug import std.format;
import std.json;
import std.stdio;
import std.typecons: tuple;

import lantana.math;
import lantana.types;

enum GLBComponentType
{
	BYTE = 5120,
	UNSIGNED_BYTE = 5121,
	SHORT = 5122,
	UNSIGNED_SHORT = 5123,
	UNSIGNED_INT = 5125,
	FLOAT = 5126,
}

string toString(GLBComponentType p_type)
{
	switch(p_type)
	{
		case GLBComponentType.BYTE: return "BYTE";
		case GLBComponentType.UNSIGNED_BYTE: return "UNSIGNED_BYTE";
		case GLBComponentType.SHORT: return "SHORT";
		case GLBComponentType.UNSIGNED_SHORT: return "UNSIGNED_SHORT";
		case GLBComponentType.UNSIGNED_INT: return "UNSIGNED_INT";
		case GLBComponentType.FLOAT: return "FLOAT";
		default: 
			debug
			{
				import std.format;
				return format("UNKNOWN[%d]", p_type);
			}
			else
			{
				return "UNKNOWN";
			}
	}
}

bool isCompatible(T)(GLBComponentType p_type) @nogc nothrow
{
	static if(isTemplateType!(Vector, T))
	{
		alias ValueType = T.dataType;
	}
	else static if(isTemplateType!(Matrix, T))
	{
		alias ValueType = T.dataType;
	}
	else static if(is(T == Quat))
	{
		alias ValueType = float;
	}
	else
	{
		alias ValueType = T;
	}
	switch(p_type)
	{
		case GLBComponentType.BYTE:
			return is(ValueType == byte);
		case GLBComponentType.UNSIGNED_BYTE:
			return is(ValueType == ubyte);
		case GLBComponentType.SHORT:
			return is(ValueType == short);
		case GLBComponentType.UNSIGNED_SHORT:
			return is(ValueType == ushort);
		case GLBComponentType.UNSIGNED_INT:
			return is(ValueType == uint);
		case GLBComponentType.FLOAT:
			return is(ValueType == float);
		default:
			return false;
	}
}

uint size(GLBComponentType p_type) pure nothrow @nogc 
{
	switch(p_type)
	{
		case GLBComponentType.BYTE:  return 1;
		case GLBComponentType.SHORT: return 2;
		case GLBComponentType.FLOAT: return 4;
		case GLBComponentType.UNSIGNED_INT:   return 4;
		case GLBComponentType.UNSIGNED_BYTE:  return 1;
		case GLBComponentType.UNSIGNED_SHORT: return 2;
		default: 
			debug printf("Invalid GLBComponentType: %u\n", p_type);
			return -1;
	}
}

enum GLBDataType
{
	SCALAR,
	VEC2,
	VEC3,
	VEC4,
	MAT2,
	MAT3,
	MAT4,
	UNKNOWN
}

bool isCompatible(T)(GLBDataType p_type)  nothrow
{
	static if(isTemplateType!(Vector, T))
	{
		switch(p_type)
		{
			case GLBDataType.VEC2:
				return T.size == 2;
			case GLBDataType.VEC3:
				return T.size == 3;
			case GLBDataType.VEC4:
				return T.size == 4;
			default:
				return false;
		}
	}
	else static if(isTemplateType!(Matrix, T))
	{
		case GLBDataType.MAT2:
			return T.rows == 2 && T.columns == 2;
		case GLBDataType.MAT3:
			return T.rows == 3 && T.columns == 3;
		case GLBDataType.Mat4:
			return T.rows == 4 && T.columns == 4;
		default:
			return false;

	}
	else
	{
		if(p_type == GLBDataType.SCALAR)
		{
			return true;
		}
		else
		{
			return false;
		}
	}
}

GLBDataType typeFromString(string p_type) 
{	switch(p_type)
	{
		case "SCALAR": return GLBDataType.SCALAR;
		case "VEC2"  : return GLBDataType.VEC2;
		case "VEC3"  : return GLBDataType.VEC3;
		case "VEC4"  : return GLBDataType.VEC4;
		case "MAT2"  : return GLBDataType.MAT2;
		case "MAT3"  : return GLBDataType.MAT3;
		case "MAT4"  : return GLBDataType.MAT4;
		default: 
			debug
				assert(false, "Invalid GLBDataType name: "~p_type);
			else 
				return GLBDataType.UNKNOWN;
	}
}

string toString(GLBDataType p_type) 
{
	switch(p_type)
	{
		case GLBDataType.SCALAR : return "SCALAR";
		case GLBDataType.VEC2   : return "VEC2";
		case GLBDataType.VEC3   : return "VEC3";
		case GLBDataType.VEC4   : return "VEC4";
		case GLBDataType.MAT2   : return "MAT2";
		case GLBDataType.MAT3   : return "MAT3";
		case GLBDataType.MAT4   : return "MAT4";
		default: 
			debug
			{
				import std.format;
				return format("UNKNOWN[%d]", p_type);
			}
			else
			{
				return "UNKNOWN";
			}
	}
}

uint componentCount(GLBDataType p_type) pure nothrow @nogc 
{
	switch(p_type)
	{
		case GLBDataType.SCALAR: return 1;
		case GLBDataType.VEC2: return 2;
		case GLBDataType.VEC3: return 3;
		case GLBDataType.VEC4: return 4;
		case GLBDataType.MAT2: return 4;
		case GLBDataType.MAT3: return 9;
		case GLBDataType.MAT4: return 16;
		default:
			debug printf("Unknown GLBDataType: %u", p_type);
			return 0;
	}
}

struct GLBBufferView
{
	// Offset in the buffer
	uint byteOffset;
	// size of array in bytes
	uint byteLength;

	GLBDataType dataType;
	GLBComponentType componentType;

	const immutable(T[]) asArray(T)(ubyte[] p_buffer)
	{
		debug import std.format;
		debug assert(dataType.isCompatible!T(), format("Incompatible dataType: %s!%s versus %s", 
			dataType.toString(), componentType.toString(), T.stringof));

		debug assert(componentType.isCompatible!T(), format("Incompatible componentType: %s!%s versus %s", 
			dataType.toString(), componentType.toString(), T.stringof));

		return cast(immutable(T[])) (cast(T*)(&p_buffer[byteOffset]))[0..count()];
	}

	this(JSONValue p_access, JSONValue[] p_views)
	{
		uint idx_buffer = cast(uint)p_access["bufferView"].integer();
		auto b = p_views[idx_buffer];

		this.componentType = cast(GLBComponentType) p_access["componentType"].integer();
		this.dataType = typeFromString(p_access["type"].str());
		this.byteOffset = cast(uint) b["byteOffset"].integer();
		this.byteLength = cast(uint) b["byteLength"].integer();
	}

	const bool isCompatible(T)()  nothrow
	{
		return dataType.isCompatible!T() && componentType.isCompatible!T();
	}

	public uint count() const pure nothrow @nogc 
	{
		return byteLength/(dataType.componentCount()*componentType.size());
	}
}

enum ImageType
{
	PNG,
	BMP,
	TGA,
	UNKNOWN
}

ImageType imageTypeFromString(string p_mime)
{
	switch(p_mime)
	{
		case "image/png":
			return ImageType.PNG;
		default:
			return ImageType.UNKNOWN;
	}
}

struct GLBImage
{
	uint byteLength;
	uint byteOffset;
	ImageType type;
}

struct GLBAccessor(Attribs)
{
	import std.format;
	import std.traits:FieldNameTuple;

	string name;
	GLBBufferView indices;

	static foreach(field; FieldNameTuple!Attribs)
	{
		mixin(format("GLBBufferView %s;", field));
	}

	void bounds(out uint start, out uint length) {
		start = indices.byteOffset;
		uint end = start + indices.byteLength;

		static foreach(field; FieldNameTuple!Attribs) {{
			uint new_start = mixin(field~".byteOffset");
			uint new_end = new_start + mixin(field~".byteLength");

			if (new_start < start) {
				start = new_start;
			}

			if(new_end > end) {
				end = new_end;
			}
		}}

		length = end - start;
	}

	void subtractOffset(uint start) {
		indices.byteOffset -= start;
		static foreach(field; FieldNameTuple!Attribs) {{
			mixin(field~".byteOffset") -= start;
		}}
	}
	GLBImage tex_albedo;
}

enum GLBAnimationPath
{
	TRANSLATION,
	ROTATION,
	SCALE,
	WEIGHTS,
	UNKNOWN
}

GLBAnimationPath pathFromString(string p_name)
{
	switch(p_name)
	{
		case "translation": return GLBAnimationPath.TRANSLATION;
		case "rotation": return GLBAnimationPath.ROTATION;
		case "weights": return GLBAnimationPath.WEIGHTS;
		case "scale": return GLBAnimationPath.SCALE;
		default: return GLBAnimationPath.UNKNOWN;
	}
}

enum GLBInterpolationMode
{
	CUBICSPLINE,
	LINEAR,
	STEP,
	UNKNOWN
}

GLBInterpolationMode interpolationFromString(string p_interp)
{
	switch(p_interp)
	{
		case "CUBICSPLINE": return GLBInterpolationMode.CUBICSPLINE;
		case "LINEAR": return GLBInterpolationMode.LINEAR;
		case "STEP": return GLBInterpolationMode.STEP;
		default: return GLBInterpolationMode.UNKNOWN;
	}
}

/// Represents a set of keyframes for a node attribute
struct GLBAnimationChannel
{
	/// The interpolation mode of each keyframe
	GLBInterpolationMode interpolation;
	/// The property to animate
	GLBAnimationPath path;
	/// Index of BufferView for keyframe times
	ushort timeBuffer;
	/// Index of the BufferView for keyframe values
	ushort valueBuffer;
	/// Index of the bone being animated
	ubyte targetBone;
}

struct GLBNode
{
	Vec3 translation;
	Vec3 scale;
	Quat rotation;
	// -1 means it has no parent
	byte parent;

	Mat4 computeMatrix() 
	{
		Mat4 result = Mat4([
			[scale.x, 0.0f,     0.0f,     0],
			[0.0f,     scale.y, 0.0f,     0],
			[0.0f,     0.0f,     scale.z, 0],
			[0.0f,     0.0f,     0.0f,  1.0f]
		]);
		result *= rotation.matrix();
		result[0, 3] = translation.x;
		result[1, 3] = translation.y;
		result[2, 3] = translation.z;

		return result;
	}

	this (JSONValue p_node)
	{
		this.translation = Vec3(0);
		this.scale = Vec3(1);
		this.rotation = Quat.identity();
		
		if("translation" in p_node)
		{
			auto tr = p_node["translation"].array();
			this.translation = Vec3(
				tr[0].type == JSONType.float_ ? tr[0].floating(): tr[0].integer(),
				tr[1].type == JSONType.float_ ? tr[1].floating(): tr[1].integer(),
				tr[2].type == JSONType.float_ ? tr[2].floating(): tr[2].integer());
		}

		if("rotation" in p_node)
		{
			auto rot = p_node["rotation"].array();

			this.rotation = Quat(
				rot[3].type == JSONType.float_ ? rot[3].floating(): rot[3].integer(),
				rot[0].type == JSONType.float_ ? rot[0].floating(): rot[0].integer(),
				rot[1].type == JSONType.float_ ? rot[1].floating(): rot[1].integer(),
				rot[2].type == JSONType.float_ ? rot[2].floating(): rot[2].integer());
		}

		if("scale" in p_node)
		{
			auto scl = p_node["scale"].array();

			this.scale = Vec3(
				scl[0].type == JSONType.float_ ? scl[0].floating(): scl[0].integer(),
				scl[1].type == JSONType.float_ ? scl[1].floating(): scl[1].integer(),
				scl[2].type == JSONType.float_ ? scl[2].floating(): scl[2].integer());
		}
		this.parent = -1;
	}
}

struct GLBAnimation
{
	string name;
	GLBAnimationChannel[] channels;
	GLBBufferView[] bufferViews;

	//debug const string toString()
	//{
	//	return format("%s [%u channels, %u buffers]", 
	//		name, channels.length, bufferViews.length);
	//}

	this(string p_name, GLBAnimationChannel[] p_channels, GLBBufferView[] p_bufferViews) @nogc
	{
		name = p_name;
		channels = p_channels;
		bufferViews = p_bufferViews;
	}
}

struct GLBSkin
{
	string name;
	GLBNode[] joints;
	ubyte inverseBindMatrices;
}

Quat getQuat(T)(Vector!(T, 4) p_val)
{
	return Quat(
		glbConvert!(float, T)(p_val.w),
		glbConvert!(float, T)(p_val.x),
		glbConvert!(float, T)(p_val.y),
		glbConvert!(float, T)(p_val.z)
	);
}

OutType glbConvert(OutType, InType)(InType p_val)
{
	import std.math;
	static if(is(OutType == InType))
	{
		return p_val;
	}
	else
	{
		static if(is(InType == byte) || is(OutType == byte))
		{
			float tmax = 127.0;
			float min = -1;
		}
		else static if(is(InType == ubyte) || is(OutType == ubyte))
		{
			float tmax = 255.0;
			float min = 0;
		}
		else static if(is(InType == short) || is(OutType == short))
		{
			float tmax = 32767.0;
			float min = -1;
		}
		else static if(is(InType == ushort) || is(OutType == ushort))
		{
			float tmax = 65535.0;
			float min = 0;
		}
		else
		{
			static assert(false, "glbConvert, invalid type combination: "~InType.stringof ~ ", "~OutType.stringof);
		}

		static if(is(OutType == float))
		{
			return fmax(p_val/tmax, min);
		}
		else static if(is(InType == float))
		{
			return cast(OutType)round(p_val * tmax);
		}
		else
		{
			static assert(false, "glbConvert, invalid type combination: "~InType.stringof ~ ", "~OutType.stringof);
		}
	}

}