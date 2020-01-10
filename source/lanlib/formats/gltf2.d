// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.formats.gltf2;

import std.file;
debug import std.format;
import std.json;
import std.stdio;

import gl3n.linalg;
import lanlib.math.func;
import lanlib.types;
import lanlib.util.memory;
import lanlib.util.array;

struct GLBStaticLoadResults
{
	GLBMeshAccessor[] accessors;
	ubyte[] data;
	/// `data[0..bufferSize]` is what's put in the vertex buffer.
	/// This will hopefully prevent junk like animations and textures from getting in the VBO,
	/// without requiring the buffer to be chopped up and copied around.
	uint bufferSize;
}

struct GLBAnimatedLoadResults
{
	GLBAnimatedAccessor[] accessors;
	GLBAnimation[] animations;
	GLBNode[] bones;
	ubyte[] data;
	GLBBufferView inverseBindMatrices;
	/// `data[0..bufferSize]` is what's put in the vertex buffer.
	/// This will hopefully prevent junk like animations and textures from getting in the VBO,
	/// without requiring the buffer to be chopped up and copied around.
	uint bufferSize;
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

bool isCompatible(T)(GLBComponentType p_type)
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

uint size(GLBComponentType p_type)
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
			debug throw new Exception(format("Invalid GLBComponentType: %u", p_type));
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
			debug throw new Exception("Invalid GLBDataType name: "~p_type);
			else return GLBDataType.UNKNOWN;
	}
}

uint componentCount(GLBDataType p_type)
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
			debug throw new Exception(format("Unknown GLBDataType: %u", p_type));
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

	static GLBBufferView fromJSON(JSONValue p_access, JSONValue[] p_views)
	{
		uint idx_buffer = cast(uint)p_access["bufferView"].integer();
		auto b = p_views[idx_buffer];

		GLBBufferView view;
		view.componentType = cast(GLBComponentType) p_access["componentType"].integer();
		view.dataType = typeFromString(p_access["type"].str());
		view.byteOffset = cast(uint) b["byteOffset"].integer();
		view.byteLength = cast(uint) b["byteLength"].integer();
		return view;
	}

	const T[] asArray(T)(ubyte[] p_buffer)
	{
		assert(componentType.isCompatible!T());

		auto len = byteLength/
			(dataType.componentCount()*componentType.size());
		return (cast(T*)(&p_buffer[byteOffset]))[0..len];
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

	static GLBNode fromJSON(JSONValue p_node)
	{
		GLBNode bone;
		bone.translation = vec3(0);
		bone.scale = vec3(1);
		bone.rotation = quat.identity();
		
		if("translation" in p_node)
		{
			auto tr = p_node["translation"].array();
			bone.translation = vec3(
				tr[0].type == JSONType.float_ ? tr[0].floating(): tr[0].integer(),
				tr[1].type == JSONType.float_ ? tr[1].floating(): tr[1].integer(),
				tr[2].type == JSONType.float_ ? tr[2].floating(): tr[2].integer());
		}

		if("rotation" in p_node)
		{
			auto rot = p_node["rotation"].array();

			bone.rotation = quat(
				rot[3].type == JSONType.float_ ? rot[3].floating(): rot[3].integer(),
				rot[0].type == JSONType.float_ ? rot[0].floating(): rot[0].integer(),
				rot[1].type == JSONType.float_ ? rot[1].floating(): rot[1].integer(),
				rot[2].type == JSONType.float_ ? rot[2].floating(): rot[2].integer());
		}

		if("scale" in p_node)
		{
			auto scl = p_node["scale"].array();

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

	static GLBAnimation fromJSON(JSONValue p_anim, JSONValue[] p_views, JSONValue[] access)
	{
		GLBAnimation a;
		a.name = p_anim["name"].str();
		debug writeln("Loading animation: ", a.name);
		auto channels = p_anim["channels"].array();
		a.channels.reserve(channels.length);

		auto samplers = p_anim["samplers"].array();
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
				a.bufferViews ~= GLBBufferView.fromJSON(in_access, p_views);
				ubyte index = cast(ubyte) (a.bufferViews.length - 1);
				chan.timeBuffer = index;
			}

			auto output_index = outputBuffers.indexOf(output);
			if(output_index < 0)
			{
				outputBuffers ~= output;
				auto in_access = access[output];
				a.bufferViews ~= GLBBufferView.fromJSON(in_access, p_views);
				ubyte index = cast(ubyte) (a.bufferViews.length - 1);
				chan.valueBuffer = index;
			}
		}
		return a;
	}

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

//Check a binary gltf2 file
auto glbLoad(bool is_animated = false)(string p_file, ILanAllocator p_alloc)
{
	assert(p_file.exists(), "File does not exist: " ~ p_file);
	debug writeln("Loading "~p_file);
	debug scope(failure) writeln("Could not load "~p_file);

	auto input = File(p_file, "rb");
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
	uint bufferMax;
	auto results = glbJsonParse!is_animated(json, p_alloc, bufferMax);
	results.bufferSize = bufferMax;

	uint[2] binaryHeader;
	input.rawRead(binaryHeader);
	assert(binaryHeader[1] == GLBChunkType.BIN, "Second chunk of a GLB must be BIN");
	
	results.data = p_alloc.make_list!ubyte(binaryHeader[0]);
	input.rawRead(results.data);

	return results;
}

auto glbJsonParse(bool is_animated)(char[] p_json, ILanAllocator p_alloc, ref uint p_bufferMax)
{
	//debug writeln(p_json);

	JSONValue scn = parseJSON(p_json);
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

		result.animations = p_alloc.make_list!GLBAnimation(anims.length);

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
		result.bones = p_alloc.make_list!GLBNode(joints.length);

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
						int parentJointIndex = -1;
						foreach(j; 0..joints.length)
						{
							if(joints[j].integer() == n)
							{
								parentJointIndex = cast(int)j;
							}
						}
						if(parentJointIndex >= 0)
						{
							result_bone.parent = cast(byte)parentJointIndex;
						}
						debug writeln(format("Joint %d has parent: %d", idx-1, parentJointIndex));
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
				ubyte jointIndex = 0;
				foreach(j; joints)
				{
					if(j.integer() == targetBone)
					{
						chan.targetBone = jointIndex;
					}
					jointIndex++;
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

		with(accessor)
		{
			indices = GLBBufferView.fromJSON(access[ac_indeces], bufferViews);
			p_bufferMax = max(p_bufferMax, indices.byteOffset + indices.byteLength);

			positions = GLBBufferView.fromJSON(access[ac_position], bufferViews);
			p_bufferMax = max(p_bufferMax, positions.byteOffset + positions.byteLength);

			normals = GLBBufferView.fromJSON(access[ac_normal], bufferViews);
			p_bufferMax = max(p_bufferMax, normals.byteOffset + normals.byteLength);

			uv = GLBBufferView.fromJSON(access[ac_uv], bufferViews);
			p_bufferMax = max(p_bufferMax, uv.byteOffset + uv.byteLength);
			
			auto material = scn["materials"][primitives["material"].integer()];
			auto idx_texture = material["pbrMetallicRoughness"]["baseColorTexture"]["index"].integer();
			auto img_albedo = scn["images"][
				scn["textures"][idx_texture]["source"].integer()
			];
			// Not used in VBO, so no change to p_bufferMax
			tex_albedo.type = imageTypeFromString(img_albedo["mimeType"].str());
			auto buf_albedo = bufferViews[img_albedo["bufferView"].integer()];
			tex_albedo.byteOffset = cast(uint) buf_albedo["byteOffset"].integer();
			tex_albedo.byteLength = cast(uint) buf_albedo["byteLength"].integer();

			static if(is_animated)
			{
				auto ac_weights = atr["WEIGHTS_0"].integer();
				auto ac_joints = atr["JOINTS_0"].integer();
				bone_weight = GLBBufferView.fromJSON(access[ac_weights], bufferViews);
				p_bufferMax = max(p_bufferMax, bone_weight.byteOffset + bone_weight.byteLength);

				bone_idx = GLBBufferView.fromJSON(access[ac_joints], bufferViews);
				p_bufferMax = max(p_bufferMax, bone_idx.byteOffset + bone_idx.byteLength);
			}
		}
	}

	return result;
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

void glbPrint(ref GLBAnimatedLoadResults p_loaded)
{
	foreach(access; p_loaded.accessors)
	{
		writeln(access.name);
		writeln("Bone indeces");
		glbPrintBuffer(access.bone_idx, p_loaded.data);
		writeln("Bone weights");
		glbPrintBuffer(access.bone_weight, p_loaded.data);
	}
}

void glbPrintBuffer(ref GLBBufferView p_view, ubyte[] p_bytes)
{
	debug assert(p_view.byteOffset < p_bytes.length, 
		format("Bad bufferView/buffer.  Buffer length: %u.  View offset: %u", p_bytes.length, p_view.byteOffset));
	switch(p_view.componentType)
	{
		case GLBComponentType.BYTE:
			printThis!byte(p_view, p_bytes);
			break;
		case GLBComponentType.UNSIGNED_BYTE:
			printThis!ubyte(p_view, p_bytes);
			break;
		case GLBComponentType.SHORT:
			printThis!short(p_view, p_bytes);
			break;
		case GLBComponentType.UNSIGNED_SHORT:
			printThis!ushort(p_view, p_bytes);
			break;
		case GLBComponentType.UNSIGNED_INT:
			printThis!uint(p_view, p_bytes);
			break;
		case GLBComponentType.FLOAT:
			printThis!float(p_view, p_bytes);
			break;
		default:
			write("Can't print componentType: ");
			writeln(p_view.componentType);
			break;
	}
}
void printThis(Type)(GLBBufferView p_view, ubyte[] p_bytes)
{
	switch(p_view.dataType)
	{
		case GLBDataType.SCALAR:
			printThisStuff!Type(p_view, p_bytes);
			break;
		case GLBDataType.VEC2:
			printThisStuff!(Type[2])(p_view, p_bytes);
			break;
		case GLBDataType.VEC3:
			printThisStuff!(Type[3])(p_view, p_bytes);
			break;
		case GLBDataType.VEC4:
			printThisStuff!(Type[4])(p_view, p_bytes);
			break;
		//case GLBDataType.MAT2:
		//	printThisStuff!(Matrix!(Type, 2, 2))(p_view, p_bytes);
		//	break;
		//case GLBDataType.MAT3:
		//	printThisStuff!(Matrix!(Type, 3, 3))(p_view, p_bytes);
		//	break;
		//case GLBDataType.MAT4:
		//	printThisStuff!(Matrix!(Type, 4, 4))(p_view, p_bytes);
		//	break;
		default:
			write("Unsupported data type: ");
			writeln(p_view.dataType);
			break;
	}
}

void printThisStuff(Type)(GLBBufferView p_view, ubyte[] p_data)
{
	uint length = p_view.byteLength/Type.sizeof;
	Type[] values = (cast(Type*)(&p_data[p_view.byteOffset]))[0..length];
	foreach(value; values)
	{
		write("\t->");
		writeln(value);
	}
}