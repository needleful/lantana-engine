// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.formats.gltf2;

debug import std.format;

enum GLBChunkType : uint
{
	JSON = 0x4E4F534A,
	BIN = 0x004E4942
}

enum GLBComponentType
{
	BYTE = 5120,
	UNSIGNED_BYTE = 5121,
	SHORT = 5122,
	UNSIGNED_SHORT = 5123,
	UNSIGNED_INT = 5125,
	FLOAT = 5126,
}

uint size(GLBComponentType type)
{
	switch(type)
	{
		case GLBComponentType.BYTE: return 1;
		case GLBComponentType.UNSIGNED_BYTE: return 1;
		case GLBComponentType.SHORT: return 2;
		case GLBComponentType.UNSIGNED_SHORT: return 2;
		case GLBComponentType.UNSIGNED_INT: return 4;
		case GLBComponentType.FLOAT: return 4;
		default: 
			debug throw new Exception(format("Invalid GLBComponentType: %u", type));
			else return -1;
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

GLBDataType fromString(string typename)
{
	switch(typename)
	{
		case "SCALAR": return GLBDataType.SCALAR;
		case "VEC2"  : return GLBDataType.VEC2;
		case "VEC3"  : return GLBDataType.VEC3;
		case "VEC4"  : return GLBDataType.VEC4;
		case "MAT2"  : return GLBDataType.MAT2;
		case "MAT3"  : return GLBDataType.MAT3;
		case "MAT4"  : return GLBDataType.MAT4;
		default: 
			debug throw new Exception("Invalid GLBDataType name: "~typename);
			else return GLBDataType.UNKNOWN;
	}
	
}

uint componentCount(GLBDataType type)
{
	switch(type)
	{
		case GLBDataType.SCALAR: return 1;
		case GLBDataType.VEC2: return 2;
		case GLBDataType.VEC3: return 3;
		case GLBDataType.VEC4: return 4;
		case GLBDataType.MAT2: return 4;
		case GLBDataType.MAT3: return 9;
		case GLBDataType.MAT4: return 16;
		default:
			debug throw new Exception(format("Unknown GLBDataType: %u", type));
			else return 0;
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
}

struct GLBMeshAccessor
{
	string name;
	GLBBufferView positions;
	GLBBufferView uv;
	GLBBufferView normals;
	GLBBufferView indices;
}