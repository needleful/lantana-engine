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
import game.map;
import game.systems;

import lantana.ecs.core;
import lantana.input;
import lantana.math;
import lantana.render;
import lantana.render.mesh.animation : AnimationSequence;
import lantana.types.collections : Stack;
import lantana.types.layout;
import lantana.types.memory;

// Degrees
float camFOV = 70;
// Degrees per second
float camSpeed = 60;

final class SceneManager
{
	public alias ECSManager = Manager!(Actors, Animations, ActorTransforms); 
	ECSManager ecsManager;

	StaticMesh.System staticMeshes;
	AnimMesh.System animatedMeshes;

	OwnedList!(StaticMesh.Instance) stInstances;
	OwnedList!(AnimMesh.Instance) anInstances;

	StaticMesh.Uniforms.global stUniforms;
	AnimMesh.Uniforms.global anUniforms;
	LightPalette palette;

	SubRegion memory;

	public
	{
		string currentScene;
		OrbitalCamera camera;
		Room room;
	}

	public this(ref BaseRegion mainMem)
	{
		ecsManager = new ECSManager();
		memory = mainMem.provideRemainder();

		staticMeshes = StaticMesh.System("data/shaders/worldspace3d.vert", "data/shaders/material3d.frag");
		animatedMeshes = AnimMesh.System("data/shaders/animated3d.vert", "data/shaders/material3d.frag");
		
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
		ecsManager.update(p_delta);
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
		ecsManager.clear();
		memory.wipe();

		palette = LightPalette("data/palettes/lightPalette.png", memory);

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

	MeshLoader[string] staticLoaders;
	MeshLoader[string] animatedLoaders;

	uint[string] files;
	
	// Each of these takes an entity as key
	string[uint] meshInstances;
	Grid.Dir[uint] actors;
	Grid.Dir[uint] props;
	ivec2[uint] gridPos;
	vec3[uint] worldPos;
	float[uint] scales;

	string name;
	Room room;
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
					"SCN_ERROR Invalid mesh (name: %s) (file: %s) (node: %s)",
					 name, m2.file, m2.node);
				return false;
			}

			bool animated = m.getAttribute!bool("animated", false);
			if(animated)
				scl.animatedLoaders[name] = m2;
			else
				scl.staticLoaders[name] = m2;

			if(!m2.file in files)
				files[m2.file] = 1;
			else
				files[m2.file] += 1;
		}

		Tag gridTag = file.getTag("grid");
		if(gridTag is null)
		{
			writefln("SCN_ERROR no grid in scene file.");
			return false;
		}
		else
		{
			
		}
		return true;
	}
}