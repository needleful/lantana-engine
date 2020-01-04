// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.formats.gltf2;

import std.file;
import std.format;
import std.json;
import std.stdio;

import gl3n.linalg;
import lanlib.types;
import lanlib.util.memory;
import lanlib.util.array;

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
	GLBBufferView inverseBindMatrices;
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

bool isCompatible(T)(GLBComponentType type)
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
		alias ValueType = Q.qt;
	}
	else
	{
		alias ValueType = T;
	}
	switch(type)
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

	const T[] asArray(T)(ubyte[] buffer)
	{
		assert(componentType.isCompatible!T());

		auto len = byteLength/
			(dataType.componentCount()*componentType.size());
		return (cast(T*)(&buffer[byteOffset]))[0..len];
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

	mat4 compute_matrix()
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

	static GLBNode fromJSON(JSONValue node)
	{
		GLBNode bone;
		bone.translation = vec3(0);
		bone.scale = vec3(1);
		bone.rotation = quat.identity();
		
		if("translation" in node)
		{
			auto tr = node["translation"].array();
			bone.translation = vec3(
				tr[0].type == JSONType.float_ ? tr[0].floating(): tr[0].integer(),
				tr[1].type == JSONType.float_ ? tr[1].floating(): tr[1].integer(),
				tr[2].type == JSONType.float_ ? tr[2].floating(): tr[2].integer());
		}

		if("rotation" in node)
		{
			auto rot = node["rotation"].array();

			bone.rotation = quat(
				rot[3].type == JSONType.float_ ? rot[3].floating(): rot[3].integer(),
				rot[0].type == JSONType.float_ ? rot[0].floating(): rot[0].integer(),
				rot[1].type == JSONType.float_ ? rot[1].floating(): rot[1].integer(),
				rot[2].type == JSONType.float_ ? rot[2].floating(): rot[2].integer());
		}

		if("scale" in node)
		{
			auto scl = node["scale"].array();

			bone.scale = vec3(
				scl[0].type == JSONType.float_ ? scl[0].floating(): scl[0].integer(),
				scl[1].type == JSONType.float_ ? scl[1].floating(): scl[1].integer(),
				scl[2].type == JSONType.float_ ? scl[2].floating(): scl[2].integer());
		}
		bone.parent = -1;
		return bone;
	}
}

struct GLBAnimation
{
	string name;
	GLBAnimationChannel[] channels;
	GLBBufferView[] bufferViews;

	static GLBAnimation fromJSON(JSONValue animation, JSONValue[] bufferViews, JSONValue[] access)
	{
		GLBAnimation a;
		a.name = animation["name"].str();
		debug writeln("Loading animation: ", a.name);
		auto channels = animation["channels"].array();
		a.channels.reserve(channels.length);

		auto samplers = animation["samplers"].array();
		// heuristic guess for bufferViews length
		a.bufferViews.reserve(samplers.length + 3);

		// Have to keep track of previously allocated buffers
		ubyte[] inputBuffers;
		ubyte[] outputBuffers;
		inputBuffers.reserve(samplers.length);
		outputBuffers.reserve(samplers.length);

		foreach(channel; channels)
		{
			a.channels.length += 1;
			auto chan = &a.channels[$-1];

			auto target = channel["target"];
			chan.targetBone = cast(ubyte) target["node"].integer();
			chan.path = pathFromString(target["path"].str());

			auto sourceSampler = channel["sampler"].integer();
			auto sampler = samplers[sourceSampler];

			chan.interpolation = interpolationFromString(sampler["interpolation"].str());

			auto input = cast(ubyte) sampler["input"].integer();
			auto output = cast(ubyte) sampler["output"].integer();

			auto input_index = inputBuffers.indexOf(input);
			if(input_index < 0)
			{
				inputBuffers ~= input;
				auto in_access = access[input];
				a.bufferViews ~= GLBBufferView.fromJSON(in_access, bufferViews);
				ubyte index = cast(ubyte) (a.bufferViews.length - 1);
				chan.timeBuffer = index;
			}

			auto output_index = outputBuffers.indexOf(output);
			if(output_index < 0)
			{
				outputBuffers ~= output;
				auto in_access = access[output];
				a.bufferViews ~= GLBBufferView.fromJSON(in_access, bufferViews);
				ubyte index = cast(ubyte) (a.bufferViews.length - 1);
				chan.valueBuffer = index;
			}
		}
		return a;
	}

	const string toString()
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

	GLBMeshAccessor mesh()
	{
		GLBMeshAccessor m;
		m.name = name;
		m.positions = positions;
		m.uv = uv;
		m.normals = normals;
		m.indices = indices;

		return m;
	}
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
	auto results = glb_json_parse!is_animated(json, meshAllocator);

	uint[2] binaryHeader;
	input.rawRead(binaryHeader);
	assert(binaryHeader[1] == GLBChunkType.BIN, "Second chunk of a GLB must be BIN");
	
	results.data = (cast(ubyte*)meshAllocator.make(binaryHeader[0]))[0..binaryHeader[0]];
	input.rawRead(results.data);

	return results;
}

auto glb_json_parse(bool is_animated)(char[] ascii_json, ILanAllocator alloc)
{
	//debug writeln(ascii_json);

	JSONValue scn = parseJSON(ascii_json);
	assert(scn.type == JSONType.object);

	auto jMeshes = scn["meshes"].array();
	auto access = scn["accessors"].array();
	auto bufferViews = scn["bufferViews"].array();

	static if(is_animated)
	{
		GLBAnimatedLoadResults result;

		auto scn_index = scn["scene"].integer();
		auto scene = scn["scenes"].array()[scn_index];
		auto anims = scn["animations"].array();

		result.animations =
			(cast(GLBAnimation*)alloc.make(anims.length*GLBAnimation.sizeof))
			[0..anims.length];

		uint idx = 0;
		foreach(animation; anims)
		{
			result.animations[idx++] = GLBAnimation.fromJSON(animation, bufferViews, access);
		}

		auto nodes = scn["nodes"].array();
		auto skin = scn["skins"].array()[0];

		auto ibm_index = skin["inverseBindMatrices"].integer();
		result.inverseBindMatrices = GLBBufferView.fromJSON(access[ibm_index], bufferViews);
		auto joints = skin["joints"].array();
		result.bones = 
			(cast(GLBNode*)alloc.make(joints.length*GLBNode.sizeof))
			[0..joints.length];

		idx = 0;
		foreach(joint; joints)
		{
			long node_idx = joint.integer();
			auto node = nodes[node_idx];

			result.bones[idx++] = GLBNode.fromJSON(node);

			auto result_bone = &result.bones[idx-1];
			// slow, naive parent retrieval but I don't give a shit
			foreach(n; 0..nodes.length)
			{
				auto test_node = nodes[n];
				if(n == node_idx || "children" !in test_node)
				{
					continue;
				}

				foreach(child; test_node["children"].array())
				{
					// Current node has a parent
					if(child.integer() == node_idx)
					{
						// is the parent part of the joints?
						int parent_joint_index = -1;
						foreach(j; 0..joints.length)
						{
							if(joints[j].integer() == n)
							{
								parent_joint_index = cast(int)j;
							}
						}
						if(parent_joint_index >= 0)
						{
							result_bone.parent = cast(byte)parent_joint_index;
						}
						writeln(format("Joint %d has parent: %d", idx-1, parent_joint_index));
					}
				}
			}
		}
		// Convert animations bone indeces to skin indeces
		foreach(anim; result.animations)
		{
			foreach(ref chan; anim.channels)
			{
				auto targetBone = chan.targetBone;
				ubyte joint_index = 0;
				foreach(j; joints)
				{
					if(j.integer() == targetBone)
					{
						chan.targetBone = joint_index;
					}
					joint_index++;
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

		if("name" in m)
		{
			accessor.name = m["name"].str();
		}
		auto ac_indeces = primitives["indices"].integer();
		auto ac_position = atr["POSITION"].integer();
		auto ac_normal = atr["NORMAL"].integer();
		auto ac_uv = atr["TEXCOORD_0"].integer();

		accessor.indices = GLBBufferView.fromJSON(access[ac_indeces], bufferViews);
		accessor.positions = GLBBufferView.fromJSON(access[ac_position], bufferViews);
		accessor.normals = GLBBufferView.fromJSON(access[ac_normal], bufferViews);
		accessor.uv = GLBBufferView.fromJSON(access[ac_uv], bufferViews);

		static if(is_animated)
		{
			auto ac_weights = atr["WEIGHTS_0"].integer();
			auto ac_joints = atr["JOINTS_0"].integer();
			accessor.bone_weight = GLBBufferView.fromJSON(access[ac_weights], bufferViews);
			accessor.bone_idx = GLBBufferView.fromJSON(access[ac_joints], bufferViews);
		}
	}

	return result;
}

OutType glb_convert(OutType, InType)(InType inval)
{
	import std.math;
	static if(is(OutType == InType))
	{
		return inval;
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
			static assert(false, "glb_convert, invalid type combination: "~InType.stringof ~ ", "~OutType.stringof);
		}

		static if(is(OutType == float))
		{
			return fmax(inval/tmax, min);
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

}

void glb_print(ref GLBAnimatedLoadResults results)
{
	foreach(access; results.accessors)
	{
		writeln(access.name);
		writeln("Bone indeces");
		glb_printBuffer(access.bone_idx, results.data);
		writeln("Bone weights");
		glb_printBuffer(access.bone_weight, results.data);
	}
}

void glb_printBuffer(ref GLBBufferView view, ubyte[] bytes)
{
	assert(view.byteOffset < bytes.length, 
		format("Bad bufferView/buffer.  Buffer length: %u.  View offset: %u", bytes.length, view.byteOffset));
	switch(view.componentType)
	{
		case GLBComponentType.BYTE:
			printThis!byte(view, bytes);
			break;
		case GLBComponentType.UNSIGNED_BYTE:
			printThis!ubyte(view, bytes);
			break;
		case GLBComponentType.SHORT:
			printThis!short(view, bytes);
			break;
		case GLBComponentType.UNSIGNED_SHORT:
			printThis!ushort(view, bytes);
			break;
		case GLBComponentType.UNSIGNED_INT:
			printThis!uint(view, bytes);
			break;
		case GLBComponentType.FLOAT:
			printThis!float(view, bytes);
			break;
		default:
			write("Can't print componentType: ");
			writeln(view.componentType);
			break;
	}
}
void printThis(Type)(GLBBufferView view, ubyte[] bytes)
{
	switch(view.dataType)
	{
		case GLBDataType.SCALAR:
			printThisStuff!Type(view, bytes);
			break;
		case GLBDataType.VEC2:
			printThisStuff!(Type[2])(view, bytes);
			break;
		case GLBDataType.VEC3:
			printThisStuff!(Type[3])(view, bytes);
			break;
		case GLBDataType.VEC4:
			printThisStuff!(Type[4])(view, bytes);
			break;
		//case GLBDataType.MAT2:
		//	printThisStuff!(Matrix!(Type, 2, 2))(view, bytes);
		//	break;
		//case GLBDataType.MAT3:
		//	printThisStuff!(Matrix!(Type, 3, 3))(view, bytes);
		//	break;
		//case GLBDataType.MAT4:
		//	printThisStuff!(Matrix!(Type, 4, 4))(view, bytes);
		//	break;
		default:
			write("Unsupported data type: ");
			writeln(view.dataType);
			break;
	}
}

void printThisStuff(Type)(GLBBufferView view, ubyte[] data)
{
	uint length = view.byteLength/Type.sizeof;
	Type[] values = (cast(Type*)(&data[view.byteOffset]))[0..length];
	foreach(value; values)
	{
		write("\t->");
		writeln(value);
	}
}