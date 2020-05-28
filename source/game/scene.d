// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.scene;

import std.format;
import std.stdio;

import bindbc.sdl;
import gl3n.linalg : vec3, vec2;
import sdlang;

import game.actor;
import game.bipple;
import game.map;
import game.systems;

import lantana.animation;
import lantana.ecs.core;
import lantana.input;
import lantana.math;
import lantana.render;
import lantana.render.mesh.animation;
import lantana.types.collections : Stack;
import lantana.types.layout;
import lantana.types.memory;

// Degrees
float camFOV = 70;
// Degrees per second
float camSpeed = 60;

final class SceneManager
{
	public alias ECSManager = Manager!(Bipples, Actors, SkeletalSystem, ActorTransforms);

public:
	StaticMesh.System staticMeshes;
	AnimMesh.System animatedMeshes;

	OwnedList!(StaticMesh.Instance) stInstances;
	OwnedList!(AnimMesh.Instance) anInstances;

	StaticMesh.Uniforms.global stUniforms;
	AnimMesh.Uniforms.global anUniforms;
	LightPalette palette;

	SubRegion memory;

	string currentScene;
	Room room;
	OrbitalCamera camera;
	ECSManager ecs;


	public this(ref BaseRegion mainMem)
	{
		ecs = new ECSManager();
		memory = mainMem.provideRemainder();

		staticMeshes = StaticMesh.System("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag");
		animatedMeshes = AnimMesh.System("data/shaders/animated3d.vert", "data/shaders/material3d.frag");
		animatedMeshes.skeletal = &ecs.get!SkeletalSystem();
		
		camera = OrbitalCamera(vec3(0), 1280.0/720.0, camFOV, vec2(0, 60));
		camera.distance = 9;

		with(stUniforms)
		{
			light_direction = vec3(0, -1, -0.2);
			light_bias = 0;
			area_span = 3;
			area_ceiling = -1.5;
			gamma = 2.2;
			static if(lnt_LogarithmicDepth)
			{
				nearPlane = camera.nearPlane;
				farPlane = camera.farPlane;
			}
			tex_albedo = 0;
		}
		with(anUniforms)
		{
			light_direction = vec3(0, -1, -0.2);
			light_bias = 0;
			area_span = 3;
			area_ceiling = -1.5;
			gamma = 2.2;
			static if(lnt_LogarithmicDepth)
			{
				nearPlane = camera.nearPlane;
				farPlane = camera.farPlane;
			}
			tex_albedo = 0;
		}
	}

	public void update(float p_delta)
	{
		ecs.update(p_delta);
		animatedMeshes.update(p_delta, anInstances.borrow());
	}

	public void render()
	{
		auto vp = camera.vp();

		stUniforms.projection = vp;
		anUniforms.projection = vp;

		staticMeshes.render(stUniforms, palette.palette, stInstances.borrow());
		animatedMeshes.render(anUniforms, palette.palette, anInstances.borrow());
	}

	public bool load(string p_file)
	{
		SceneLoader scl;

		if(!SceneLoader.fromFile(p_file, scl))
		{
			return false;
		}

		currentScene = "";
		animatedMeshes.clearMeshes();
		staticMeshes.clearMeshes();
		stInstances.clear();
		anInstances.clear();
		ecs.clear();
		memory.wipe();

		palette = LightPalette("data/palettes/lightPalette.png", memory);

		room = Room(scl.room.center, scl.room.start, scl.room.end, memory);
		currentScene = scl.name;

		AnimMesh.Mesh*[string][string] animLoaded;
		StaticMesh.Mesh*[string][string] staticLoaded;

		AnimMesh.Mesh*[string] anim;
		StaticMesh.Mesh*[string] stat;

		animatedMeshes.reserveMeshes(memory, cast(uint)scl.animatedLoaders.length + 3);
		anInstances = memory.makeOwnedList!(AnimMesh.Instance)(cast(uint)scl.animatedInstances.length);

		foreach(name, mesh; scl.animatedLoaders)
		{
			if(mesh.file !in animLoaded)
				animLoaded[mesh.file] = animatedMeshes.loadMeshes(mesh.file, memory);
			anim[name] = animLoaded[mesh.file][mesh.node];
		}

		staticMeshes.reserveMeshes(memory, cast(uint)scl.staticLoaders.length + 3);
		stInstances = memory.makeOwnedList!(StaticMesh.Instance)(cast(uint)scl.staticInstances.length);

		foreach(name, mesh; scl.staticLoaders)
		{
			if(mesh.file !in staticLoaded)
				staticLoaded[mesh.file] = staticMeshes.loadMeshes(mesh.file, memory);
			stat[name] = staticLoaded[mesh.file][mesh.node];
		}

		ecs.reserve!Bipples(memory, cast(uint)scl.bipples.length);
		ecs.reserve!Actors(memory, cast(uint)scl.actors.length);
		ecs.reserve!ActorTransforms(memory, cast(uint) scl.actors.length);
		//ecs.reserve!Sequences(memory, cast(uint) scl.actors.length);
		//ecs.reserve!AnimOverlays(memory, cast(uint) scl.actors.length);

		for(uint i = 0; i < scl.entityCount; i++)
		{
			Transform getTransform(uint i)
			{
				float s = i in scl.scales? scl.scales[i] : 1;
				Transform transform = Transform(s);

				if(i in scl.props)
					transform.rotateDegrees(0, Grid.dirAngles[scl.props[i]], 0);

				if(i in scl.gridPos)
					transform.translate(room.getWorldPosition(scl.gridPos[i]));
				else if(i in scl.worldPos)
					transform.translate(scl.worldPos[i]);

				return transform;
			}

			if(i in scl.usables)
			{
				ivec2 pos;
				Grid.Dir dir;
				
				if(i !in scl.gridPos)
					writefln("SCN_WARNING usable `%s` has no gridPos, using origin.", scl.usables[i]);
				else
					pos = scl.gridPos[i];
				
				if(i in scl.actors)
					dir = scl.actors[i];
				else if(i in scl.props)
					dir = scl.props[i];

				room.addUsable(scl.usables[i], pos, dir);
			}

			if(i in scl.actors)
			{
				if(i in scl.worldPos)
					writefln("SCN_WARNING actors ignore world position (3 values), use 2 values for grid position");

				ivec2 pos = i in scl.gridPos? scl.gridPos[i] : ivec2(0);
				auto a = ecs.get!Actors.add(Actor(&room, pos));
				a.direction = scl.actors[i];

				if(i in scl.animatedInstances)
				{
					string an = scl.animatedInstances[i];
					auto inst = anInstances.place(anim[an], Transform(1), memory, animatedMeshes);
					a.meshInst = inst;
					//a.sequence = ecs.get!Sequences.add(
					//	AnimationSequence(&(inst.anim), inst.mesh.animations));

					ecs.get!ActorTransforms.add(a, &(inst.transform));
				}
				else
				{
					writefln("SCN_WARNING no animated mesh attached to actor. This will cause crashing!");
				}
				if(i in scl.staticInstances)
				{
					string st = scl.staticInstances[i];
					auto inst = stInstances.place(stat[st], Transform(1));
					ecs.get!ActorTransforms.add(a, &(inst.transform));
				}
				
				if(i in scl.bipples)
				{
					auto b = ecs.get!Bipples.add(Bipple(scl.bipples[i]));
					b.actor = a;
				}
			}
			else if(i in scl.bipples)
			{
				ecs.get!Bipples.add(Bipple(scl.bipples[i]));
			}

			if(i in scl.props)
			{
				if(i in scl.gridPos)
				{
					room.grid.removePoint(scl.gridPos[i]);
				}
			}

			if(i !in scl.actors)
			{
				if(i in scl.staticInstances)
				{
					string st = scl.staticInstances[i];
					stInstances.place(stat[st], getTransform(i));
				}
				if(i in scl.animatedInstances)
				{
					string an = scl.animatedInstances[i];
					anInstances.place(anim[an], getTransform(i), memory, animatedMeshes);
				}
			}
		}

		return true;
	}
}

struct SceneLoader
{
	struct MeshLoader
	{
		string file;
		string node;
	}

	struct RoomDescriptor
	{
		vec3 center;
		ivec2 start, end;
	}

	MeshLoader[string] staticLoaders;
	MeshLoader[string] animatedLoaders;

	uint[string] files;
	
	// Map of named entities
	uint[string] entities;	
	// Each of these takes an entity as key
	string[uint] staticInstances;
	string[uint] animatedInstances;
	Grid.Dir[uint] actors;
	Grid.Dir[uint] props;
	string[uint] usables;
	ivec2[uint] gridPos;
	vec3[uint] worldPos;
	float[uint] scales;
	ushort[uint] bipples;

	string name;
	RoomDescriptor room;
	uint entityCount = 0;

	static bool fromFile(string p_file, out SceneLoader scl)
	{
		Tag file = parseFile(p_file);

		scl.name = file.getTagValue!string("scene", "<no name>");

		foreach(m; file.tags["mesh"])
		{
			MeshLoader m2;
			string name = m.getValue!string("");
			m2.file = m.getAttribute!string("file", "");
			m2.node = m.getAttribute!string("node", "");

			if(name == "" || m2.file == "" || m2.node == "")
			{
				writefln(
					"SCN_FAILURE Invalid mesh (name: %s) (file: %s) (node: %s)",
					 name, m2.file, m2.node);
				return false;
			}

			bool animated = m.getAttribute!bool("animated", false);
			if(animated)
				scl.animatedLoaders[name] = m2;
			else
				scl.staticLoaders[name] = m2;

			if(m2.file !in scl.files)
				scl.files[m2.file] = 1;
			else
				scl.files[m2.file] += 1;
		}

		Tag gridTag = file.getTag("grid");
		if(gridTag is null)
		{
			writefln("SCN_FAILURE no grid in scene file.");
			return false;
		}
		else
		{
			Value[] center = gridTag.getTagValues("position");
			if(center is null || center.length != 3)
			{
				writefln("SCN_WARNING missing or invalid grid position in %s", p_file);
				scl.room.center = vec3(0);
			}
			else
			{
				scl.room.center = vec3(
					center[0].get!double(),
					center[1].get!double(),
					center[2].get!double());
			}

			Value[] start = gridTag.getTagValues("start");
			if(start is null || start.length != 2)
			{
				writefln("SCN_WARNING grid start is missing or invalid, defaulting to (-5, -5)");
			}
			else 
			{
				scl.room.start = ivec2(
					start[0].get!int(),
					start[1].get!int());
			}

			Value[] end = gridTag.getTagValues("end");
			if(end is null || end.length != 2)
			{
				writefln("SCN_WARNING grid end is missing or invalid, defaulting to (-5, -5)");
			}
			else 
			{
				scl.room.end = ivec2(
					end[0].get!int(),
					end[1].get!int());
			}
		}

		foreach(e; file.tags["entity"])
		{
			Tag mesh = e.getTag("mesh-instance");
			if(mesh !is null)
			{
				string s = mesh.getValue!string("");
				if(s == "")
				{
					writefln("SCN_FAILURE missing name for mesh-instance on entity %s", scl.entityCount);
					return false;
				}
				if(s in scl.animatedLoaders)
				{
					scl.animatedInstances[scl.entityCount] = s;
				}
				else if(s in scl.staticLoaders)
				{
					scl.staticInstances[scl.entityCount] = s;
				}
				else
				{
					writefln("SCN_FAILURE mesh '%s' has no mesh loaded", s);
					return false;
				}
			}

			int bipple = e.getTagValue!int("bipple", -1);
			if(bipple >= 0)
			{
				scl.bipples[scl.entityCount] = cast(ushort) bipple;
			}

			Tag actor = e.getTag("actor");
			if(actor !is null)
			{
				string s = actor.getAttribute!string("direction", "UP");
				scl.actors[scl.entityCount] = dirFromString(s);
			}

			Tag prop = e.getTag("prop");
			if(prop !is null)
			{
				string s = prop.getAttribute!string("direction", "UP");
				scl.props[scl.entityCount] = dirFromString(s);
			}

			Value[] pos = e.getTagValues("position");
			if(pos !is null)
			{
				if(pos.length < 2 || pos.length > 3)
				{
					writefln("SCN_WARNING improper position, defaulting to 0,0,0 worldspace");
					scl.worldPos[scl.entityCount] = vec3(0);
				}
				else if(pos.length == 2)
				{
					scl.gridPos[scl.entityCount] = ivec2(
						pos[0].get!int(),
						pos[1].get!int());
				}
				else if(pos.length == 3)
				{
					scl.worldPos[scl.entityCount] = vec3(
						cast(float)pos[0].get!double(),
						cast(float)pos[1].get!double(),
						cast(float)pos[2].get!double());
				}
			}

			Tag scale = e.getTag("scale");
			if(scale !is null)
			{
				float s = cast(float) scale.getValue!double(1);
				int si = scale.getValue!int(1);

				if(s != 1)
					scl.scales[scl.entityCount] = s;
				else
					scl.scales[scl.entityCount] = si;
			}

			string usable = e.getTagValue("usable", "");
			if(usable != "")
			{
				scl.usables[scl.entityCount] = usable;
			}
			scl.entityCount++;
		}
		return true;
	}
}