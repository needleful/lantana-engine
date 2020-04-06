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

import render.mesh.attributes;


enum GLBChunkType : uint
{
	JSON = 0x4E4F534A,
	BIN = 0x004E4942
}

struct GLBLoadResults(Spec)
	if(isTemplateType!(MeshSpec, Spec))
{
	static if(Spec.isAnimated)
	{
		GLBAnimation[] animations;
		GLBNode[] bones;
		GLBBufferView inverseBindMatrices;
	}
	ubyte[] data;
	Spec.accessor accessor;

	/// `data[0..bufferSize]` is what's put in the vertex buffer.
	/// This will hopefully prevent junk like animations and textures from getting in the VBO,
	/// without requiring the buffer to be chopped up and copied around.
	uint bufferSize;
}

struct GLBLoadMap(Spec)
	if(isTemplateType!(MeshSpec, Spec))
{
	struct MeshData
	{
		static if(Spec.isAnimated)
		{
			GLBAnimation[] animations;
			GLBNode[] bones;
			GLBBufferView inverseBindMatrices;
		}
		Spec.accessor accessor;
	}
	MeshData[string] meshes;
}

//Check a binary gltf2 file
auto glbLoad(Spec)(string p_file, ref Region p_alloc)
	if(isTemplateType!(MeshSpec, Spec))
{
	assert(p_file.exists(), "File does not exist: " ~ p_file);

	auto input = File(p_file, "rb");
	uint[3] header;
	input.rawRead(header);
	assert(header[0] == 0x46546C67, "Invalid magic number: " ~ header[0].stringof);

	uint[2] jsonHeader;
	input.rawRead(jsonHeader);

	assert(jsonHeader[1] == GLBChunkType.JSON, "First chunk of a GLB file must be JSON");
	char[] json;
	json.length = jsonHeader[0];
	input.rawRead(json);

	auto results = glbJsonParse!Spec(json, p_alloc);

	uint[2] binaryHeader;
	input.rawRead(binaryHeader);
	assert(binaryHeader[1] == GLBChunkType.BIN, "Second chunk of a GLB must be BIN");
	
	results.data = p_alloc.makeList!ubyte(binaryHeader[0]);
	input.rawRead(results.data);

	return results;
}

GLBLoadMap!Spec glbLoadMulti(Spec)(string p_file, ref Region p_alloc)
{

}

private auto glbJsonParse(Spec)(char[] p_json, ref Region p_alloc)
	if(isTemplateType!(MeshSpec, Spec))
{
	scope(failure) writeln(p_json);
	JSONValue scn = parseJSON(p_json);
	assert(scn.type == JSONType.object);

	auto jMeshes = scn["meshes"].array();
	assert(jMeshes.length == 1, "Cannot process GLB files with multiple meshes");

	GLBLoadResults!Spec result;

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

	auto access = scn["accessors"].array();
	auto bufferViews = scn["bufferViews"].array();

	with(result.accessor)
	{
		auto ac_indeces = primitives["indices"].integer();

		indices = GLBBufferView(access[ac_indeces], bufferViews);
		result.bufferSize = max(result.bufferSize, indices.byteOffset + indices.byteLength);

		static foreach(field; Spec.attribType.fields)
		{{
			// Double brackets so the same name can be reused
			auto ac = atr[mixin("Spec.loader."~field)].integer();

			mixin(field) = GLBBufferView(access[ac], bufferViews);
			result.bufferSize = max(result.bufferSize, mixin(field).byteOffset + mixin(field).byteLength);
		}}
		
		auto material = scn["materials"][primitives["material"].integer()];
		auto idx_texture = material["pbrMetallicRoughness"]["baseColorTexture"]["index"].integer();
		auto img_albedo = scn["images"][
			scn["textures"][idx_texture]["source"].integer()
		];

		tex_albedo.type = imageTypeFromString(img_albedo["mimeType"].str());
		auto buf_albedo = bufferViews[img_albedo["bufferView"].integer()];
		tex_albedo.byteOffset = cast(uint) buf_albedo["byteOffset"].integer();
		tex_albedo.byteLength = cast(uint) buf_albedo["byteLength"].integer();
	}

	static if(Spec.isAnimated)
	{
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

	return result;
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