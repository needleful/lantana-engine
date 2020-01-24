// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.gltf2.glb;

import std.file;
debug import std.format;
import std.json;
import std.stdio;
import std.typecons: tuple;

import gl3n.linalg;
import lanlib.gltf2.types;
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
	GLBMeshAccessor[] accessors;
	ubyte[] data;
	/// `data[0..bufferSize]` is what's put in the vertex buffer.
	/// This will hopefully prevent junk like animations and textures from getting in the VBO,
	/// without requiring the buffer to be chopped up and copied around.
	uint bufferSize;
}

struct GLBAnimatedLoadResults
{
	immutable(GLBAnimatedAccessor[]) accessors;
	immutable(GLBAnimation[]) animations;
	immutable(GLBNode[]) bones;
	immutable(ubyte[]) data;
	immutable(GLBBufferView) inverseBindMatrices;
	/// `data[0..bufferSize]` is what's put in the vertex buffer.
	/// This will hopefully prevent junk like animations and textures from getting in the VBO,
	/// without requiring the buffer to be chopped up and copied around.
	immutable(uint) bufferSize;

	@disable this();

	this(
		immutable(GLBAnimatedAccessor[]) p_accessor,
		immutable(GLBAnimation[]) p_animations,
		immutable(GLBNode[]) p_bones,
		immutable(ubyte[]) p_data,
		immutable(GLBBufferView) p_ibm)
	{
		accessors = p_accessor;
		animations = p_animations;
		bones = p_bones;
		data = p_data;
		inverseBindMatrices = p_ibm;
	}
}

//Check a binary gltf2 file
auto glbLoad(bool animated = false)(string p_file, ILanAllocator p_alloc)
{
	assert(p_file.exists(), "File does not exist: " ~ p_file);
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
	auto results = glbJsonParse!animated(json, p_alloc, bufferMax);
	results.bufferSize = bufferMax;

	uint[2] binaryHeader;
	input.rawRead(binaryHeader);
	assert(binaryHeader[1] == GLBChunkType.BIN, "Second chunk of a GLB must be BIN");
	
	results.data = p_alloc.makeList!ubyte(binaryHeader[0]);
	input.rawRead(results.data);

	return results;
}

auto glbJsonParse(bool animated)(char[] p_json, ILanAllocator p_alloc, ref uint p_bufferMax)
{
	//debug writeln(p_json);

	JSONValue scn = parseJSON(p_json);
	assert(scn.type == JSONType.object);

	auto jMeshes = scn["meshes"].array();
	auto access = scn["accessors"].array();
	auto bufferViews = scn["bufferViews"].array();

	static if(animated)
	{
		auto scn_index = scn["scene"].integer();
		auto scene = scn["scenes"].array()[scn_index];
		auto anims = scn["animations"].array();

		auto animations = p_alloc.makeList!GLBAnimation(anims.length);

		uint idx = 0;
		foreach(animation; anims)
		{
			result.animations[idx++] = animationFromJSON(animation, bufferViews, access);
		}

		auto nodes = scn["nodes"].array();
		auto skin = scn["skins"].array()[0];

		auto ibm_index = skin["inverseBindMatrices"].integer();
		auto inverseBindMatrices = bufferFromJSON(access[ibm_index], bufferViews);

		auto joints = skin["joints"].array();
		auto bones = p_alloc.makeList!GLBNode(joints.length);

		idx = 0;
		foreach(joint; joints)
		{
			long node_idx = joint.integer();
			auto node = nodes[node_idx];

			result.bones[idx++] = nodeFromJSON(node);

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
			indices = bufferFromJSON(access[ac_indeces], bufferViews);
			p_bufferMax = max(p_bufferMax, indices.byteOffset + indices.byteLength);

			positions = bufferFromJSON(access[ac_position], bufferViews);
			p_bufferMax = max(p_bufferMax, positions.byteOffset + positions.byteLength);

			normals = bufferFromJSON(access[ac_normal], bufferViews);
			p_bufferMax = max(p_bufferMax, normals.byteOffset + normals.byteLength);

			uv = bufferFromJSON(access[ac_uv], bufferViews);
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
				bone_weight = bufferFromJSON(access[ac_weights], bufferViews);
				p_bufferMax = max(p_bufferMax, bone_weight.byteOffset + bone_weight.byteLength);

				bone_idx = bufferFromJSON(access[ac_joints], bufferViews);
				p_bufferMax = max(p_bufferMax, bone_idx.byteOffset + bone_idx.byteLength);
			}
		}
	}
	return result;
}

auto glbJsonParseAnimated(char[] p_json, ILanAllocator p_alloc, ref uint p_bufferMax)
{
	//debug writeln(p_json);

	JSONValue scn = parseJSON(p_json);
	assert(scn.type == JSONType.object);

	auto jMeshes = scn["meshes"].array();
	auto access = scn["accessors"].array();
	auto bufferViews = scn["bufferViews"].array();

	static if(animated)
	{
		auto scn_index = scn["scene"].integer();
		auto scene = scn["scenes"].array()[scn_index];
		auto anims = scn["animations"].array();

		auto animations = p_alloc.makeList!GLBAnimation(anims.length);

		uint idx = 0;
		foreach(animation; anims)
		{
			result.animations[idx++] = animationFromJSON(animation, bufferViews, access);
		}

		auto nodes = scn["nodes"].array();
		auto skin = scn["skins"].array()[0];

		auto ibm_index = skin["inverseBindMatrices"].integer();
		auto inverseBindMatrices = bufferFromJSON(access[ibm_index], bufferViews);
		
		auto joints = skin["joints"].array();
		auto bones = p_alloc.makeList!GLBNode(joints.length);

		idx = 0;
		foreach(joint; joints)
		{
			long node_idx = joint.integer();
			auto node = nodes[node_idx];

			result.bones[idx++] = nodeFromJSON(node);

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
			indices = bufferFromJSON(access[ac_indeces], bufferViews);
			p_bufferMax = max(p_bufferMax, indices.byteOffset + indices.byteLength);

			positions = bufferFromJSON(access[ac_position], bufferViews);
			p_bufferMax = max(p_bufferMax, positions.byteOffset + positions.byteLength);

			normals = bufferFromJSON(access[ac_normal], bufferViews);
			p_bufferMax = max(p_bufferMax, normals.byteOffset + normals.byteLength);

			uv = bufferFromJSON(access[ac_uv], bufferViews);
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
				bone_weight = bufferFromJSON(access[ac_weights], bufferViews);
				p_bufferMax = max(p_bufferMax, bone_weight.byteOffset + bone_weight.byteLength);

				bone_idx = bufferFromJSON(access[ac_joints], bufferViews);
				p_bufferMax = max(p_bufferMax, bone_idx.byteOffset + bone_idx.byteLength);
			}
		}
	}
	return result;
}

GLBBufferView bufferFromJSON(JSONValue p_access, JSONValue[] p_views)
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


GLBNode nodeFromJSON(JSONValue p_node)
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

GLBAnimation animationFromJSON(JSONValue p_anim, JSONValue[] p_views, JSONValue[] access)
{
	GLBAnimation a;
	a.name = p_anim["name"].str();
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
			a.bufferViews ~= bufferFromJSON(in_access, p_views);
			ubyte index = cast(ubyte) (a.bufferViews.length - 1);
			chan.timeBuffer = index;
		}

		auto output_index = outputBuffers.indexOf(output);
		if(output_index < 0)
		{
			outputBuffers ~= output;
			auto in_access = access[output];
			a.bufferViews ~= bufferFromJSON(in_access, p_views);
			ubyte index = cast(ubyte) (a.bufferViews.length - 1);
			chan.valueBuffer = index;
		}
	}
	return a;
}