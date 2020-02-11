// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module audio.driver;

import std.concurrency : ownerTid, send, receive;

import bindbc.openal;

enum AudioInitStatus
{
	Failure,
	Success
}

private enum AudioSource
{
	Music = 0,
}

ALCdevice* g_device;
ALCcontext* g_context;
ALuint[] g_buffers;
ALuint[] g_sources;

private AudioInitStatus initialize()
{
	ALSupport ret = loadOpenAL();

	if(ret != ALSupport.al11)
	{
		return AudioInitStatus.Failure;
	}

	g_device = alcOpenDevice(null);
	if(g_device == null)
	{
		return AudioInitStatus.Failure;
	}

	g_context =  alcCreateContext(g_device, null);
	if(g_context == null)
	{
		return AudioInitStatus.Failure;
	}

	alcMakeContextCurrent(g_context);

	g_buffers.length = 1;
	alGenBuffers(cast(int)g_buffers.length, g_buffers.ptr);

	g_sources.length = 1;
	alGenSources(cast(int)g_sources.length, g_sources.ptr);

	alSourcei(g_sources[AudioSource.Music], AL_BUFFER, g_buffers[AudioSource.Music]);
	alSourcei(g_sources[AudioSource.Music], AL_LOOPING, AL_TRUE);

	if(alGetError() != AL_NO_ERROR)
	{
		return AudioInitStatus.Failure;
	}

	return AudioInitStatus.Success;
}

void runAudio()
{
	auto status = initialize();
	ownerTid.send(status);
	if(status != AudioInitStatus.Success)
	{
		// Cannot go on
		return;
	}
	scope(exit)
	{
		alcMakeContextCurrent(null);
		alDeleteSources(cast(int)g_sources.length, g_sources.ptr);
		alDeleteBuffers(cast(int)g_buffers.length, g_buffers.ptr);
		alcDestroyContext(g_context);
		alcCloseDevice(g_device);
	}
}