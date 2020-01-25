// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.gltf2.types;

debug import std.format;
import std.stdio;

import gl3n.linalg;

import lanlib.types;

enum GLBComponentType
{
	BYTE = 5120,
	UNSIGNED_BYTE = 5121,
	SHORT = 5122,
	UNSIGNED_SHORT = 5123,
	UNSIGNED_INT = 5125,
	FLOAT = 5126,
}

string toString(GLBComponentType p_type)  nothrow
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
			//debug
			//{
			//	import std.format;
			//	return format("UNKNOWN[%d]", p_type);
			//}
			//else
			//{
				return "UNKNOWN";
			//}
	}
}

bool isCompatible(T)(GLBComponentType p_type)  nothrow
{
	static if(isTemplateType!(Vector, T))
	{
		alias ValueType = T.vt;
	}
	else static if(isTemplateType!(Matrix, T))
	{
		alias ValueType = T.mt;
	}
	else static if(isTemplateType!(Quaternion, T))
	{
		alias ValueType = T.qt;
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

uint size(GLBComponentType p_type)  nothrow
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
			//debug throw new Exception(format("Invalid GLBComponentType: %u", p_type));
			//else
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
				return T.dimension == 2;
			case GLBDataType.VEC3:
				return T.dimension == 3;
			case GLBDataType.VEC4:
				return T.dimension == 4;
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
		case GLBDataType.MAT4:
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
{
	switch(p_type)
	{
		case "SCALAR": return GLBDataType.SCALAR;
		case "VEC2"  : return GLBDataType.VEC2;
		case "VEC3"  : return GLBDataType.VEC3;
		case "VEC4"  : return GLBDataType.VEC4;
		case "MAT2"  : return GLBDataType.MAT2;
		case "MAT3"  : return GLBDataType.MAT3;
		case "MAT4"  : return GLBDataType.MAT4;
		default: 
			//debug throw new Exception("Invalid GLBDataType name: "~p_type);
			//else 
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
			//debug
			//{
			//	import std.format;
			//	return format("UNKNOWN[%d]", p_type);
			//}
			//else
			//{
				return "UNKNOWN";
			//}
	}
}

uint componentCount(GLBDataType p_type)  nothrow
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

		auto len = byteLength/
			(dataType.componentCount()*componentType.size());
		return cast(immutable(T[])) (cast(T*)(&p_buffer[byteOffset]))[0..len];
	}

	const bool isCompatible(T)()  nothrow
	{
		return dataType.isCompatible!T() && componentType.isCompatible!T();
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

struct GLBMeshAccessor
{
	string name;
	GLBBufferView positions;
	GLBBufferView uv;
	GLBBufferView normals;
	GLBBufferView indices;
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
	ubyte timeBuffer;
	/// Index of the BufferView for keyframe values
	ubyte valueBuffer;
	/// Index of the bone being animated
	ubyte targetBone;
}

struct GLBNode
{
	vec3 translation;
	vec3 scale;
	quat rotation;
	// -1 means it has no parent
	byte parent;

	mat4 computeMatrix() 
	{
		mat4 result = mat4(
			vec4(scale.x, 0.0f,     0.0f,     0),
			vec4(0.0f,     scale.y, 0.0f,     0),
			vec4(0.0f,     0.0f,     scale.z, 0),
			vec4(0.0f,     0.0f,     0.0f,  1.0f)
		);
		result *= rotation.to_matrix!(4,4)();
		result[0][3] = translation.x;
		result[1][3] = translation.y;
		result[2][3] = translation.z;

		return result;
	}
}

struct GLBAnimation
{
	string name;
	GLBAnimationChannel[] channels;
	GLBBufferView[] bufferViews;

	debug const string toString()
	{
		return format("%s [%u channels, %u buffers]", 
			name, channels.length, bufferViews.length);
	}
}

struct GLBSkin
{
	string name;
	GLBNode[] joints;
	ubyte inverseBindMatrices;
}

struct GLBAnimatedAccessor
{
	string name;
	GLBBufferView positions;
	GLBBufferView uv;
	GLBBufferView normals;
	GLBBufferView indices;
	GLBBufferView bone_idx;
	GLBBufferView bone_weight;
	GLBImage tex_albedo;

	GLBMeshAccessor mesh()
	{
		GLBMeshAccessor m;
		m.name = name;
		m.positions = positions;
		m.uv = uv;
		m.normals = normals;
		m.indices = indices;
		m.tex_albedo = tex_albedo;

		return m;
	}
}

quat getQuat(T)(Vector!(T, 4) p_val)
{
	return quat(
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