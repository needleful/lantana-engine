

module lantana.ui.keyboard;

public struct key {
	enum modifiers: ubyte {
		none = 0x0,
		shift = 0x1,
		control = 0x2,
		alt = 0x4
	}
	char c;
	modifiers mods = modifiers.none;

	this(char p_key) {
		c = p_key;
	}

	key ctrl() {
		mods |= modifiers.control;
		return this;
	}

	key alt() {
		mods |= modifiers.alt;
		return this;
	}

	key shift() {
		mods |= modifiers.shift;
		return this;
	}

	string toString() {
		import std.conv: to;
		import std.string: capitalize;

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
		text ~= capitalize(to!string(c));
		return text;
	}

	ushort toInt() {
		ushort hi = cast(ushort) mods << 8;
		return cast(ushort) (hi + c);
	}
}