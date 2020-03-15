// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.dialog;

public final class Dialog
{
	alias Callback = void delegate(Dialog message);
	public string message;
	public float pauseTime;
	public string date;
	public Dialog[] responses;

	this(string p_message, float p_pause, Dialog[] p_responses, string p_date = "")
	{
		pauseTime = p_pause;
		message = p_message;
		responses = p_responses;
		date = p_date;
	}
}

public final Dialog testDialog()
{
	Dialog start = new Dialog("we\"re out of orbit", 2, []);

	Dialog justSaying = 
		new Dialog("i just wanted to say", 1,[
			new Dialog("I love you.", 0.8, [

			]),
			new Dialog("there was a problem", 2, [

			])
		]);

	start.responses = [
		new Dialog("hey", 0.3, 
		[
			
		], "2:41 PM"),

		new Dialog("Hi Boto", 0.3, 
		[
			justSaying,
			new Dialog("how are you?", 2, 
			[
				new Dialog("wait you can't send replies when i;m in space", 4, 
				[
					new Dialog("god dammit", 1, 
					[

					]),
					new Dialog("its fine.", 2, [justSaying])
				])
			])
		], "2:41 PM"),
		new Dialog("the ship exploded.", 0.3,
		[
			new Dialog("it fucking exploded", 0.6,
			[
			])
		], "2:41 PM"),
	];

	return start;
}