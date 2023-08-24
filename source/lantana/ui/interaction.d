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

	/// If p_focused is false, the item was released by pressing and
	/// then removing focus while holding the button.
	/// This will generally not call any effects. 
	public void release(bool p_focused);

	public void interact();

	public bool canDrag();

	public void drag(iVec2 p_dragAmount);

	// When selecting elements, overlapping elements are selected based on maximum priority (undefined if they overlap and are the same)
	public short priority();
}

public interface Scrollable {
	public void scroll(iVec2 p_scrollAmount);
}