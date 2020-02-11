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
		Tid auTid = spawn(&runAudio);

		auto status = receiveOnly!AudioInitStatus();
		if(status == AudioInitStatus.Failure)
		{
			throw new Exception("Failed to initialize audio");
		}

		return AudioManager(auTid);
	}
}