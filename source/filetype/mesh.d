// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

// For importing mesh files
module filetype.mesh;

import std.file;
import std.format;
import std.json;
import std.stdio;

import lanlib.math.vector;
import lanlib.sys.memory;

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
	GLBComponentType componentType;
	GLBDataType dataType;
	// Which buffer to load from
	uint buffer;
	// Offset in the buffer
	uint byteOffset;
	// count of elements, not of bytes
	uint count;

	uint elementSize()
	{
		return componentType.size()*dataType.componentCount();
	}
	uint byteSize()
	{
		return count*elementSize();
	}
}

struct GLBMeshAccessor
{
	string name;
	GLBBufferView view_positions;
	GLBBufferView view_uv;
	GLBBufferView view_normals;
	GLBBufferView view_indeces;
}

struct MeshDescriptor
{
	string name;
	Vec3[] vertices;
	Vec3[] normals;
	Vec2[] uv0;
	ushort[] elements;
}

//Check a binary gltf2 file
MeshDescriptor[] glb_load(string file, ILanAllocator meshAllocator)
{
	assert(file.exists(), "File does not exist: " ~ file);

	auto input = File(file, "rb");
	uint[3] header;
	input.rawRead(header);
	assert(header[0] == 0x46546C67, "Invalid magic number: " ~ header[0].stringof);

	// We won't use the version (header[1]) or length (header[2])

	uint[2] jsonHeader;
	input.rawRead(jsonHeader);

	assert(jsonHeader[1] == GLBChunkType.JSON, "First chunk of a GLB file must be JSON");
	char[] json;
	json.length = jsonHeader[0];
	input.rawRead(json);
	GLBMeshAccessor[] accessors = glb_json_parse(json);

	uint[2] binaryHeader;
	input.rawRead(binaryHeader);
	assert(binaryHeader[1] == GLBChunkType.BIN, "Second chunk of a GLB must be BIN");
	ubyte[] data = (cast(ubyte*)meshAllocator.make(binaryHeader[0]))[0..binaryHeader[0]];
	input.rawRead(data);

	MeshDescriptor[] meshes;
	meshes.reserve(accessors.length);

	T[] fromBufferView(T)(ubyte[] buffer, GLBBufferView view)
	{
		static if(is(T == uint))
		{
			assert(view.componentType == GLBComponentType.UNSIGNED_INT, 
				format("Incorrect CLBComponentType for %s: %u", T.stringof, view.componentType));
			assert(view.dataType == GLBDataType.SCALAR);
		}
		else static if(is(T == ushort))
		{
			assert(view.componentType == GLBComponentType.UNSIGNED_SHORT, 
				format("Incorrect CLBComponentType for %s: %u", T.stringof, view.componentType));
			assert(view.dataType == GLBDataType.SCALAR);
		}
		else static if(is(T == ubyte))
		{
			assert(view.componentType == GLBComponentType.UNSIGNED_BYTE, 
				format("Incorrect CLBComponentType for %s: %u", T.stringof, view.componentType));
			assert(view.dataType == GLBDataType.SCALAR);
		}
		else static if(is(T == short))
		{
			assert(view.componentType == GLBComponentType.SHORT, 
				format("Incorrect CLBComponentType for %s: %u", T.stringof, view.componentType));
			assert(view.dataType == GLBDataType.SCALAR);
		}
		else static if(is(T == byte))
		{
			assert(view.componentType == GLBComponentType.BYTE, 
				format("Incorrect CLBComponentType for %s: %u", T.stringof, view.componentType));
			assert(view.dataType == GLBDataType.SCALAR);
		}
		else static if(is(T == Vec2))
		{
			assert(view.componentType == GLBComponentType.FLOAT, 
				format("Incorrect CLBComponentType for %s: %u", T.stringof, view.componentType));
			assert(view.dataType == GLBDataType.VEC2);
		}
		else static if(is(T == Vec3))
		{
			assert(view.componentType == GLBComponentType.FLOAT, 
				format("Incorrect CLBComponentType for %s: %u", T.stringof, view.componentType));
			assert(view.dataType == GLBDataType.VEC3);
		}
		else
		{
			assert(false, "Unsupported vertex dataType: "~T.stringof);
		}
		uint start = view.byteOffset/T.sizeof;
		uint end = start + view.count;

		T[] res = (cast(T*) buffer.ptr)[start..end];
		assert(res.length == view.count);
		return res;
	}

	foreach(a; accessors)
	{
		meshes.length += 1;
		auto mesh = &meshes[$-1];

		mesh.name = a.name;
		mesh.vertices = fromBufferView!Vec3(data, a.view_positions);
		mesh.normals = fromBufferView!Vec3(data, a.view_normals);
		mesh.uv0 = fromBufferView!Vec2(data, a.view_uv);
		mesh.elements = fromBufferView!ushort(data, a.view_indeces);
	}

	return meshes;
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

		accessor.view_indeces = fromJSON(access[ac_indeces], bufferViews);
		accessor.view_positions = fromJSON(access[ac_position], bufferViews);
		accessor.view_normals = fromJSON(access[ac_normal], bufferViews);
		accessor.view_uv = fromJSON(access[ac_uv], bufferViews);
	}

	return accessors;
}

GLBBufferView fromJSON(JSONValue accessor, JSONValue[] bufferViews)
{
	uint idx_buffer = cast(uint)accessor["bufferView"].integer();
	auto b = bufferViews[idx_buffer];

	GLBBufferView view;
	view.componentType = cast(GLBComponentType) accessor["componentType"].integer();
	view.dataType = fromString(accessor["type"].str());
	view.count = cast(uint) accessor["count"].integer();

	view.buffer = cast(uint) b["buffer"].integer();
	view.byteOffset = cast(uint) b["byteOffset"].integer();

	debug
	{
		uint byteCount = cast(uint) b["byteLength"].integer();
		assert(view.byteSize() == byteCount);
	}

	return view;
}