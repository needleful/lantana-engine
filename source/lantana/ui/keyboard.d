// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.ui.keyboard;

import std.uni: toUpper, toLower;
import bindbc.sdl;

public struct key {
	enum modifiers: ubyte {
		none = 0x0,
		shift = 0x1,
		control = 0x2,
		alt = 0x4
	}
	char c;
	modifiers mods = modifiers.none;

	this(char p_key) nothrow {
		c = cast(char) toLower(p_key);
	}

	this(SDL_Keysym keysym) nothrow {
		this(SDL_GetKeyName(keysym.sym)[0]);
		auto m = keysym.mod;
		if(m & (KMOD_LSHIFT | KMOD_RSHIFT)){
			shift();
		}
		if(m & (KMOD_LALT | KMOD_RALT)) {
			alt();
		}
		if(m & (KMOD_RCTRL | KMOD_LCTRL)) {
			ctrl();
		}
	}

	key ctrl() nothrow {
		mods |= modifiers.control;
		return this;
	}

	key alt() nothrow {
		mods |= modifiers.alt;
		return this;
	}

	key shift() nothrow {
		mods |= modifiers.shift;
		return this;
	}

	string toString() {

		string text = "";
		if(mods & modifiers.alt) {
			text ~= "Alt+";
		}
		if(mods & modifiers.control) {
			text ~= "Ctrl+";
		}
		if(mods & modifiers.shift) {
			text ~= "Shift+"; 
		}
		text ~= toUpper(c);
		return text;
	}

	ushort toInt() nothrow {
		ushort hi = cast(ushort) mods << 8;
		return cast(ushort) (hi + c);
	}
}