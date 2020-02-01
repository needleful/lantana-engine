// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.interaction;

import ui.layout;

public interface Interactible
{
	alias Callback = void delegate(Widget source);
	
	public void focus();

	public void unfocus();

	public void interact();
}