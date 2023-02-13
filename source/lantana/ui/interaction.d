// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.ui.interaction;

import lantana.input;
import lantana.math.vectors : iVec2;
import lantana.ui.widgets;

public interface Interactible
{
	alias Callback = void delegate(Widget source);
	alias DragCallback = void delegate(iVec2 dragAmount);
	
	public void focus();

	public void unfocus();

	public void release();

	public void interact();

	public void drag(iVec2 p_dragAmount);

	// When selecting elements, overlapping elements are selected based on maximum priority (undefined if they overlap and are the same)
	public short priority();
}