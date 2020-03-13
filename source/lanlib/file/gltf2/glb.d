// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.file.gltf2.glb;

import std.file;
debug import std.format;
import std.json;
import std.stdio;
import std.typecons: tuple;

import gl3n.linalg;
import lanlib.file.gltf2.types;
import lanlib.math.func;
import lanlib.types;
import lanlib.util.memory;
import lanlib.util.array;


enum GLBChunkType : uint
{
	JSON = 0x4E4F534A,
	BIN = 0x004E4942
}

struct GLBStaticLoadResults
{
	ubyte[] data;
	GLBMeshAccessor accessor;
	/// `data[0..bufferSize]` is what's put in the vertex buffer.
	/// This will hopefully prevent junk like animations and textures from getting in the VBO,
	/// without requiring the buffer to be chopped up and copied around.
	uint bufferSize;
}

struct GLBAnimatedLoadResults
{
	GLBAnimation[] animations;
	GLBNode[] bones;
	ubyte[] data;
	GLBAnimatedAccessor accessor;
	GLBBufferView inverseBindMatrices;
	/// `data[0..bufferSize]` is what's put in the vertex buffer.
	/// This will hopefully prevent junk like animations and textures from getting in the VBO,
	/// without requiring the buffer to be chopped up and copied around.
	uint bufferSize;
}

//Check a binary gltf2 file
auto glbLoad(bool animated = false)(string p_file, ref Region p_alloc)
{
	assert(p_file.exists(), "File does not exist: " ~ p_file);
	//debug scope(failure) writeln("Could not load "~p_file);

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
	auto results = glbJsonParse!animated(json, p_alloc, bufferMax);
	results.bufferSize = bufferMax;

	uint[2] binaryHeader;
	input.rawRead(binaryHeader);
	assert(binaryHeader[1] == GLBChunkType.BIN, "Second chunk of a GLB must be BIN");
	
	results.data = p_alloc.makeList!ubyte(binaryHeader[0]);
	input.rawRead(results.data);

	return results;
}

auto glbJsonParse(bool animated)(char[] p_json, ref Region p_alloc, ref uint p_bufferMax)
{
	//debug writeln(p_json);

	JSONValue scn = parseJSON(p_json);
	assert(scn.type == JSONType.object);

	auto jMeshes = scn["meshes"].array();
	auto access = scn["accessors"].array();
	auto bufferViews = scn["bufferViews"].array();

	static if(animated)
	{
		GLBAnimatedLoadResults result;

		auto scn_index = scn["scene"].integer();
		auto scene = scn["scenes"].array()[scn_index];
		auto anims = scn["animations"].array();

		result.animations = p_alloc.makeList!GLBAnimation(anims.length);

		uint idx = 0;
		foreach(animation; anims)
		{
			result.animations[idx++] = animationFromJSON(p_alloc, animation, bufferViews, access);
		}

		auto nodes = scn["nodes"].array();
		auto skin = scn["skins"].array()[0];

		auto ibm_index = skin["inverseBindMatrices"].integer();
		result.inverseBindMatrices = GLBBufferView(access[ibm_index], bufferViews);
		auto joints = skin["joints"].array();
		result.bones = p_alloc.makeList!GLBNode(joints.length);

		idx = 0;
		foreach(joint; joints)
		{
			long node_idx = joint.integer();
			auto node = nodes[node_idx];

			result.bones.place(idx++, node);

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
					}
				}
			}
		}
		// Convert animations bone indeces to skin indeces
		foreach(ref anim; result.animations)
		{
			foreach(ref chan; anim.channels)
			{
				auto targetBone = chan.targetBone;
				ubyte jointIndex = 0;
				foreach(ref j; joints)
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

	assert(jMeshes.length == 1, "Cannot process GLB files with multiple meshes");

	auto m = jMeshes[0];

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
		result.accessor.name = p_alloc.copy(m["name"].str());
	}
	auto ac_indeces = primitives["indices"].integer();
	auto ac_position = atr["POSITION"].integer();
	auto ac_normal = atr["NORMAL"].integer();
	auto ac_uv = atr["TEXCOORD_0"].integer();

	with(result.accessor)
	{
		indices = GLBBufferView(access[ac_indeces], bufferViews);
		p_bufferMax = max(p_bufferMax, indices.byteOffset + indices.byteLength);

		position = GLBBufferView(access[ac_position], bufferViews);
		p_bufferMax = max(p_bufferMax, position.byteOffset + position.byteLength);

		normal = GLBBufferView(access[ac_normal], bufferViews);
		p_bufferMax = max(p_bufferMax, normal.byteOffset + normal.byteLength);

		uv = GLBBufferView(access[ac_uv], bufferViews);
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

		static if(animated)
		{
			auto ac_weights = atr["WEIGHTS_0"].integer();
			auto ac_joints = atr["JOINTS_0"].integer();
			bone_weight = GLBBufferView(access[ac_weights], bufferViews);
			p_bufferMax = max(p_bufferMax, bone_weight.byteOffset + bone_weight.byteLength);

			bone_idx = GLBBufferView(access[ac_joints], bufferViews);
			p_bufferMax = max(p_bufferMax, bone_idx.byteOffset + bone_idx.byteLength);
		}
	}
	return result;
}

void glbPrint(ref GLBAnimatedLoadResults p_loaded)
{
	writeln(p_loaded.accessor.name);
	writeln("Bone indeces");
	glbPrintBuffer(p_loaded.accessor.bone_idx, p_loaded.data);
	writeln("Bone weights");
	glbPrintBuffer(p_loaded.accessor.bone_weight, p_loaded.data);
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
void printThis(Type)(ref GLBBufferView p_view, ubyte[] p_bytes)
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

void printThisStuff(Type)(ref GLBBufferView p_view, ubyte[] p_data)
{
	uint length = p_view.byteLength/Type.sizeof;
	Type[] values = (cast(Type*)(&p_data[p_view.byteOffset]))[0..length];
	foreach(value; values)
	{
		write("\t->");
		writeln(value);
	}
}

GLBAnimation animationFromJSON(ref Region p_alloc, JSONValue p_anim, JSONValue[] p_views, JSONValue[] access)
{
	auto jchan = p_anim["channels"].array();
	auto samplers = p_anim["samplers"].array();

	// Indices into the bufferViews array
	ushort[] buffers;
	foreach(ref sampler; samplers)
	{
		auto input = cast(ushort) sampler["input"].integer();
		auto output = cast(ushort) sampler["output"].integer();

		if(buffers.indexOf(input) < 0)
		{
			buffers ~= input;
		}
		if(buffers.indexOf(output) < 0)
		{
			buffers ~= output;
		}
	}

	GLBAnimation anim;
	anim.name = p_alloc.copy(p_anim["name"].str());
	anim.channels = p_alloc.makeList!GLBAnimationChannel(jchan.length);
	anim.bufferViews = p_alloc.makeList!GLBBufferView(buffers.length);

	foreach(animIndex, bufferIndex; buffers)
	{
		anim.bufferViews.place(cast(uint) animIndex, access[bufferIndex], p_views);
	}

	foreach(index, ref channel; jchan)
	{
		auto sourceSampler = channel["sampler"].integer();
		auto sampler = samplers[sourceSampler];
		auto target = channel["target"];


		auto chan = &anim.channels[index];
		chan.targetBone = cast(ubyte) target["node"].integer();
		chan.path = pathFromString(target["path"].str());

		chan.interpolation = interpolationFromString(sampler["interpolation"].str());

		auto input = cast(ushort) sampler["input"].integer();
		auto output = cast(ushort) sampler["output"].integer();

		auto timeIdx = buffers.indexOf(input);
		auto valIdx = buffers.indexOf(output);

		assert(timeIdx >= 0);
		assert(valIdx >= 0);

		chan.timeBuffer = cast(ushort) timeIdx;
		chan.valueBuffer = cast(ushort) valIdx;
	}

	return anim;
}