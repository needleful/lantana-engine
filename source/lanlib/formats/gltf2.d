// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.formats.gltf2;

import std.file;
import std.format;
import std.json;
import std.stdio;

import lanlib.math.vector;
import lanlib.sys.memory;

struct GLBLoadResults
{
	GLBMeshAccessor[] accessors;
	ubyte[] data;
}

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

enum GLBAnimationType
{
	TRANSLATION,
	ROTATION,
	SCALE,
	UNKNOWN
}

struct GLBAnimationAccessor
{
	GLBBufferView buffer;
	uint target_node;
	GLBAnimationType type;
}

//Check a binary gltf2 file
GLBLoadResults glb_load(string file, ILanAllocator meshAllocator)
{
	assert(file.exists(), "File does not exist: " ~ file);

	auto input = File(file, "rb");
	uint[3] header;
	input.rawRead(header);
	// We won't bother checking the version (header[1]) or length (header[2])
	assert(header[0] == 0x46546C67, "Invalid magic number: " ~ header[0].stringof);

	GLBLoadResults results;

	uint[2] jsonHeader;
	input.rawRead(jsonHeader);

	assert(jsonHeader[1] == GLBChunkType.JSON, "First chunk of a GLB file must be JSON");
	char[] json;
	json.length = jsonHeader[0];
	input.rawRead(json);
	results.accessors = glb_json_parse(json);

	uint[2] binaryHeader;
	input.rawRead(binaryHeader);
	assert(binaryHeader[1] == GLBChunkType.BIN, "Second chunk of a GLB must be BIN");
	results.data = (cast(ubyte*)meshAllocator.make(binaryHeader[0]))[0..binaryHeader[0]];
	input.rawRead(results.data);

	return results;
}

GLBMeshAccessor[] glb_json_parse(char[] ascii_json)
{
	//debug writeln(ascii_json);
	
	JSONValue[] jMeshes, access, bufferViews;
	{
		JSONValue scn = parseJSON(ascii_json);
		assert(scn.type == JSONType.object);

		auto json_mesh = scn["meshes"];
		assert(json_mesh.type == JSONType.array);
		jMeshes = json_mesh.array();

		auto json_access = scn["accessors"];
		assert(json_access.type == JSONType.array);

		access = json_access.array();


		auto json_buffer = scn["bufferViews"];
		assert(json_buffer.type == JSONType.array);

		bufferViews = json_buffer.array();
	}

	GLBMeshAccessor[] accessors;
	accessors.reserve(jMeshes.length);
	
	GLBBufferView fromJSON(JSONValue accessor, JSONValue[] bufferViews)
	{
		uint idx_buffer = cast(uint)accessor["bufferView"].integer();
		auto b = bufferViews[idx_buffer];

		GLBBufferView view;
		view.componentType = cast(GLBComponentType) accessor["componentType"].integer();
		view.dataType = fromString(accessor["type"].str());
		view.byteOffset = cast(uint) b["byteOffset"].integer();
		view.byteLength = cast(uint) b["byteLength"].integer();
		return view;
	}
	foreach(ref m; jMeshes)
	{
		accessors.length += 1;
		auto accessor = &accessors[$-1];

		JSONValue primitives, atr;
		{
			auto prim_json = m["primitives"];
			assert(prim_json.type == JSONType.array);
			auto prim = prim_json.array();
			assert(prim.length == 1, "Do not know how to handle glTF meshes with multiple primitive sets");
			primitives = prim[0];

			atr = primitives["attributes"];
			assert(atr.type == JSONType.object);
		}

		accessor.name = m["name"].str();
		uint ac_indeces = cast(uint) primitives["indices"].integer();
		uint ac_position = cast(uint) atr["POSITION"].integer();
		uint ac_normal = cast(uint) atr["NORMAL"].integer();
		uint ac_uv = cast(uint) atr["TEXCOORD_0"].integer();

		accessor.indices = fromJSON(access[ac_indeces], bufferViews);
		accessor.positions = fromJSON(access[ac_position], bufferViews);
		accessor.normals = fromJSON(access[ac_normal], bufferViews);
		accessor.uv = fromJSON(access[ac_uv], bufferViews);
	}

	return accessors;
}
