// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module audio;

import std.concurrency;

import audio.driver;

struct AudioManager
{
	private Tid driveThread;

	@disable this();

	private this(Tid p_thread)
	{
		driveThread = p_thread;
	}

	static AudioManager initialize()
	{
		return AudioManager(spawn(&runAudio));
	}
}