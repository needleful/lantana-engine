// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module systems.render.ui;

import lanlib.sys.window;
import derelict.imgui.imgui;

struct UIRenderer
{
	Window *window;
	this(Window *window)
	{
		this.window = window;
		DerelictImgui.load();
	}
}