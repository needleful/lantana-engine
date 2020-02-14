// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module audio.driver;

import core.thread: Thread;
import core.time: dur;
import std.concurrency;

import bindbc.sdl.mixer;


struct AudioManager
{
	// Only one music channel for now
	Mix_Music* music;

	// Between 0 and 128
	private ubyte musicVolume;

	this(ubyte p_musicVolume)
	{
		SDLMixerSupport support = loadSDLMixer();

		assert(support != SDLMixerSupport.noLibrary && support != SDLMixerSupport.badLibrary);

		int mixInit = MIX_INIT_OGG;
		assert((Mix_Init(mixInit) & mixInit) == mixInit);

		assert(Mix_OpenAudio( 44100, MIX_DEFAULT_FORMAT, 2, 2048) >= 0 );

		Mix_VolumeMusic(p_musicVolume);
		musicVolume = p_musicVolume;
	}

	public bool startMusic(string p_file, int p_fadeInMs = 0)
	{
		if(music)
		{
			Mix_FreeMusic(music);
		}

		music = Mix_LoadMUS(p_file.ptr);
		int res = Mix_FadeInMusic(music, -1, p_fadeInMs);

		return res == 0;
	}

	public void setMusicVolume(ubyte p_volume)
	{
		musicVolume = p_volume;
		Mix_VolumeMusic(p_volume);
	}

	~this()
	{
		if(music)
		{
			Mix_FreeMusic(music);
		}
		Mix_Quit();
	}
}