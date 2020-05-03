// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.edit.undo;

struct ReversibleEvent
{
	void delegate() undo;
	void delegate() redo;

	this(void delegate() p_undo, void delegate() p_redo)
	{
		undo = p_undo;
		redo = p_redo;
	}
}

ReversibleEvent changedValue(T)(ref T p_value, T p_old, T p_new)
{
	return ReversibleEvent(
		() {
			p_value = p_old;
		},
		() {
			p_value = p_new;
		}
	);
}