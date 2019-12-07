// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.formats.gltf2;

import std.file;
import std.format;
import std.json;
import std.stdio;

import gl3n.linalg;
import lanlib.sys.memory;

struct GLBStaticLoadResults
{
	GLBMeshAccessor[] accessors;
	ubyte[] data;
}

struct GLBAnimatedLoadResults
{
	GLBAnimatedAccessor[] accessors;
	GLBAnimation[] animations;
	GLBNode[] bones;
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
		case GLBComponentType.BYTE:  return 1;
		case GLBComponentType.SHORT: return 2;
		case GLBComponentType.FLOAT: return 4;
		case GLBComponentType.UNSIGNED_INT:   return 4;
		case GLBComponentType.UNSIGNED_BYTE:  return 1;
		case GLBComponentType.UNSIGNED_SHORT: return 2;
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

GLBDataType typeFromString(string typename)
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

	static GLBBufferView fromJSON(JSONValue accessor, JSONValue[] bufferViews)
	{
		uint idx_buffer = cast(uint)accessor["bufferView"].integer();
		auto b = bufferViews[idx_buffer];

		GLBBufferView view;
		view.componentType = cast(GLBComponentType) accessor["componentType"].integer();
		view.dataType = typeFromString(accessor["type"].str());
		view.byteOffset = cast(uint) b["byteOffset"].integer();
		view.byteLength = cast(uint) b["byteLength"].integer();
		return view;
	}
}

struct GLBMeshAccessor
{
	string name;
	GLBBufferView positions;
	GLBBufferView uv;
	GLBBufferView normals;
	GLBBufferView indices;
}

enum GLBAnimationPath
{
	TRANSLATION,
	ROTATION,
	SCALE,
	WEIGHTS,
	UNKNOWN
}

GLBAnimationPath pathFromString(string pathname)
{
	switch(pathname)
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

GLBInterpolationMode interpolationFromString(string interp)
{
	switch(interp)
	{
		case "CUBICSPLINE": return GLBInterpolationMode.CUBICSPLINE;
		case "LINEAR": return GLBInterpolationMode.LINEAR;
		case "STEP": return GLBInterpolationMode.STEP;
		default: return GLBInterpolationMode.UNKNOWN;
	}
}

struct GLBAnimationChannel
{
	GLBAnimationPath path;
	ubyte targetBone;
	ubyte sourceSampler;
}

struct GLBAnimationSampler
{
	GLBBufferView sourceBuffer;
	GLBBufferView targetBuffer;
	GLBInterpolationMode interpolation;
}

struct GLBNode
{
	mat4 transform;
	// -1 means it has no parent
	byte parent;

	static GLBNode fromJSON(JSONValue node)
	{
		GLBNode bone;
		vec3 translation = vec3(0);
		vec3 scale = vec3(1);
		quat rotation = quat.identity();
		
		if("translation" in node)
		{
			auto tr = node["translation"].array();
			translation = vec3(
				tr[0].type == JSONType.float_ ? tr[0].floating(): tr[0].integer(),
				tr[1].type == JSONType.float_ ? tr[1].floating(): tr[1].integer(),
				tr[2].type == JSONType.float_ ? tr[2].floating(): tr[2].integer());
		}

		if("rotation" in node)
		{
			auto rot = node["rotation"].array();

			rotation = quat(
				rot[0].type == JSONType.float_ ? rot[0].floating(): rot[0].integer(),
				rot[1].type == JSONType.float_ ? rot[1].floating(): rot[1].integer(),
				rot[2].type == JSONType.float_ ? rot[2].floating(): rot[2].integer(),
				rot[3].type == JSONType.float_ ? rot[3].floating(): rot[3].integer());
		}

		if("scale" in node)
		{
			auto scl = node["scale"].array();

			scale = vec3(
				scl[0].type == JSONType.float_ ? scl[0].floating(): scl[0].integer(),
				scl[1].type == JSONType.float_ ? scl[1].floating(): scl[1].integer(),
				scl[2].type == JSONType.float_ ? scl[2].floating(): scl[2].integer());
		}

		bone.transform = mat4(
			vec4(scale.x, 0.0f,     0.0f,     0),
			vec4(0.0f,     scale.y, 0.0f,     0),
			vec4(0.0f,     0.0f,     scale.z, 0),
			vec4(0.0f,     0.0f,     0.0f,  1.0f)
		);
		bone.transform *= rotation.to_matrix!(4,4)();
		bone.transform[0][3] = translation.x;
		bone.transform[1][3] = translation.y;
		bone.transform[2][3] = translation.z;

		bone.parent = -1;

		return bone;
	}
}

struct GLBAnimation
{
	string name;
	GLBAnimationChannel[] channels;
	GLBAnimationSampler[] samplers;

	static GLBAnimation fromJSON(JSONValue animation, JSONValue[] bufferViews, JSONValue[] access)
	{
		GLBAnimation a;
		a.name = animation["name"].str();

		auto channels = animation["channels"].array();
		a.channels.reserve(channels.length);

		auto samplers = animation["samplers"].array();
		a.samplers.reserve(samplers.length);

		foreach(channel; channels)
		{
			a.channels.length += 1;
			auto chan = &a.channels[$-1];

			chan.sourceSampler = cast(ubyte) channel["sampler"].integer();

			auto target = channel["target"];
			chan.targetBone = cast(ubyte) target["node"].integer();
			chan.path = pathFromString(target["path"].str());
		}
		foreach(sampler; samplers)
		{
			a.samplers.length += 1;
			auto samp = &a.samplers[$-1];

			samp.interpolation = interpolationFromString(sampler["interpolation"].str());

			auto input = cast(ubyte) sampler["input"].integer();
			auto output = cast(ubyte) sampler["output"].integer();

			auto in_access = access[input];
			auto out_access = access[output];

			samp.sourceBuffer = GLBBufferView.fromJSON(in_access, bufferViews);
			samp.targetBuffer = GLBBufferView.fromJSON(out_access, bufferViews);
		}
		return a;
	}
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
}

//Check a binary gltf2 file
auto glb_load(bool is_animated = false)(string file, ILanAllocator meshAllocator)
{
	assert(file.exists(), "File does not exist: " ~ file);

	auto input = File(file, "rb");
	uint[3] header;
	input.rawRead(header);
	// We won't bother checking the version (header[1]) or length (header[2])
	assert(header[0] == 0x46546C67, "Invalid magic number: " ~ header[0].stringof);

	uint[2] jsonHeader;
	input.rawRead(jsonHeader);

	assert(jsonHeader[1] == GLBChunkType.JSON, "First chunk of a GLB file must be JSON");
	char[] json;
	json.length = jsonHeader[0];
	input.rawRead(json);
	auto results = glb_json_parse!is_animated(json);

	uint[2] binaryHeader;
	input.rawRead(binaryHeader);
	assert(binaryHeader[1] == GLBChunkType.BIN, "Second chunk of a GLB must be BIN");
	results.data = (cast(ubyte*)meshAllocator.make(binaryHeader[0]))[0..binaryHeader[0]];
	input.rawRead(results.data);

	return results;
}

auto glb_json_parse(bool is_animated)(char[] ascii_json)
{
	//debug writeln(ascii_json);
	
	JSONValue[] jMeshes, access, bufferViews;

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

	static if(is_animated)
	{
		auto scn_index = scn["scene"].integer();
		auto jscenes = scn["scenes"];
		
		assert(jscenes.type == JSONType.array);
		auto scenes = jscenes.array();

		auto scene = scenes[scn_index];

		auto jrootnodes = scene["nodes"];
		auto root_nodes = jrootnodes.array();

		auto jnodes = scn["nodes"];
		auto nodes = jnodes.array();

		auto janim = scn["animations"];
		auto anims = janim.array();

		GLBAnimatedLoadResults result;

		result.bones.reserve(nodes.length);
		result.animations.reserve(anims.length);

		foreach(animation; anims)
		{
			result.animations ~= GLBAnimation.fromJSON(animation, bufferViews, access);
		}
		foreach(node; nodes)
		{
			result.bones ~= GLBNode.fromJSON(node);
		}
		// Populate 'parent' field of bones
		foreach(ulong idx_bone; 0..nodes.length-1)
		{
			auto node = nodes[idx_bone];
			if("children" in node)
			{
				auto children = node["children"].array();
				foreach(child; children)
				{
					result.bones[child.integer()].parent = cast(byte)idx_bone;
				}
			}
		}
	}
	else
	{
		GLBStaticLoadResults result;
	}

	result.accessors.reserve(jMeshes.length);
	
	foreach(ref m; jMeshes)
	{
		result.accessors.length += 1;
		auto accessor = &result.accessors[$-1];

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

		accessor.indices = GLBBufferView.fromJSON(access[ac_indeces], bufferViews);
		accessor.positions = GLBBufferView.fromJSON(access[ac_position], bufferViews);
		accessor.normals = GLBBufferView.fromJSON(access[ac_normal], bufferViews);
		accessor.uv = GLBBufferView.fromJSON(access[ac_uv], bufferViews);

		static if(is_animated)
		{
			uint ac_weights = cast(uint) atr["WEIGHTS_0"].integer();
			uint ac_joints = cast(uint) atr["JOINTS_0"].integer();
			accessor.bone_weight = GLBBufferView.fromJSON(access[ac_weights], bufferViews);
			accessor.bone_idx = GLBBufferView.fromJSON(access[ac_joints], bufferViews);
		}
	}

	return result;
}

OutType glb_convert(OutType, InType)(InType inval)
{
	import std.math;
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
		static assert(false, "glb_convert, invalid type combination: "~InType.stringof ~ ", "~OutType.stringof);
	}

	static if(is(OutType == float))
	{
		return max(inval/tmax, min);
	}
	else static if(is(InType == float))
	{
		return cast(OutType)round(inval * tmax);
	}
	else
	{
		static assert(false, "glb_convert, invalid type combination: "~InType.stringof ~ ", "~OutType.stringof);
	}
}