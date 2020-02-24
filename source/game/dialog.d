// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.dialog;

public final class Dialog
{
	public string id;
	public float pauseTime;
	public string message;
	public Dialog[] responses;

	this(string p_id, string p_message, float p_pause, Dialog[] p_responses)
	{
		id = p_id;
		pauseTime = p_pause;
		message = p_message;
		responses = p_responses;
	}
}

public final Dialog testDialog()
{
	Dialog start = new Dialog("00-start", "[down with the sickness voice] oh wahaha", 2, []);

	start.responses = [
		new Dialog("01-a", "henlo", 0.3, [
			new Dialog("02-o", "i am  funny and nead", .2, [
				new Dialog("03-o", "Just kidding, i am ALONE and SAD! \n ha !\n\n ha", 22, [
					new Dialog("uu-hakasho", "i'm pretty sad, honesyly", 60, [
						new Dialog("uu2-end", "ok bye", 2, [start])
					]),
					start,
				]),
			]),
			new Dialog("02-d", "depression ??", .2, [
				new Dialog("04-x", "depression ??", .2, [
					start
				]),
				new Dialog("04-f", "Mambo... \nNumber..\n...\n\nFive.", 4, [
					start
				]),
				new Dialog("04-q", "depression ??", .2, [
					start
				]),
			]),
			new Dialog("02-f", "Mambo... \nNumber..\n...\n\nFive.", 4, [
				start
			]),
			new Dialog("02-q", "depression ??", .2, [
				start, start, start, start, start
			]),
		]),
		start
	];

	return start;
}