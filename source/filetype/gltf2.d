// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

// For importing gltf2 files
module filetype.gltf2;

import std.file;
import std.format;
import std.json;
import std.stdio;

public import lanlib.formats.gltf2;
import lanlib.math.vector;
import lanlib.sys.memory;

struct GLBLoadResults
{
	GLBMeshAccessor[] accessors;
	ubyte[] data;
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
