// Part of NP-ToDo
// copyright Devin Lee Hastings a.k.a. needleful

module app.todo;

import std.file;
import std.stdio;
import std.string: split, join;

struct Task {
	string summary;
	string notes;
	string[] tags = [];
	int priority;
	Task[] subTasks = [];
	int startTime;
	int completeTime;
}

struct Project {
	string[string] info;
	Task[] tasks = [];
}

struct View {
	string[] requiredTags = [];
	string[] excludedTags = [];
	string titleSearch;
	int minPriority;
	bool showCompleted;
}

/// Non-crashing exceptions for NP-ToDo
class NptException : Exception {
	this(string message, string file = __FILE__, size_t line = __LINE__) {
		super(message, file, line);
	}
}

Project loadProject(string path) {
	import std.ascii;
	import std.conv;
	import std.regex;

	static auto rKeyValue = regex(r"^\(([^:]*): (.*)\)$", "m");
	static auto rSummary = regex(r"^(\s*)- (.*)$", "m");
	static auto rNotes = regex(r"^(\s*)/ (.*)$", "m");
	static auto rPriority = regex(r"^(\s*)@ (.*)$", "m");
	static auto rTags = regex(r"^(\s*)# (.*)$", "m");

	if (!exists(path)) {
		throw new NptException("Project file was not found: "~path);
	}

	auto pfile = File(path, "r");

	Project result;
	struct ParsingTask {
		Task task;
		uint depth;
		this(Task t, uint indent) {
			task = t;
			depth = indent;
		}
	}

	ParsingTask[] parsed_tasks;

	// Get the index to the most recent parsed task of a lower indentation
	int findTask(uint depth) {
		for(auto i = parsed_tasks.length - 1; i >= 0; i--) {
			if(parsed_tasks[i].depth < depth) {
				return cast(int) i;
			}
		}
		return -1;
	}

	foreach(string line; lines(pfile)) {
		uint line_indent = 0;
		if(auto kv = matchFirst(line, rKeyValue)) {
			string key = kv[1];
			result.info[kv[1]] = kv[2];
		}
		else if(auto task = matchFirst(line, rSummary)) {
			Task t = Task();
			t.summary = task[2];
			uint indent = cast(uint) task[1].length;
			parsed_tasks ~= ParsingTask(t, indent);
		}
		else if(auto prio = matchFirst(line, rPriority)) {
			uint indent = cast(uint) prio[1].length;
			parsed_tasks[findTask(indent)].task.priority = to!uint(prio[2]);
		}
		else if(auto notes = matchFirst(line, rNotes)) {
			uint indent = cast(uint) notes[1].length;
			Task* t = &parsed_tasks[findTask(indent)].task;
			if(t.notes.length > 0) {
				t.notes ~= "\n" ~ notes[2];
			}
			else {
				t.notes = notes[2];
			}
		}
		else if(auto tags = matchFirst(line, rTags)) {
			uint indent = cast(uint) tags[1].length;
			Task* t = &parsed_tasks[findTask(indent)].task;
			string[] tagList = tags[2].split("; ");
			t.tags ~= tagList;
		}
		else{
			writefln("ERROR: Unidentified text: %s", line);
		}
	}

	foreach(ref ParsingTask pt; parsed_tasks) {
		if(pt.depth == 0) {
			result.tasks ~= pt.task;
			continue;
		}

		Task* latest = &result.tasks[$-1];
		for(uint level = 1; level < pt.depth; level ++) {
			if(!result.tasks.length) {
				break;
			}
			latest = &latest.subTasks[$-1];
		}
		latest.subTasks ~= pt.task;
	}

	return result;
}

void storeProject(ref Project project, string path) {
	auto outFile = File(path, "w");
	foreach(string key, string value; project.info) {
		outFile.writefln("(%s: %s)", key, value);
	}
	writeTasks(outFile, project.tasks, 0);
}

void writeTasks(ref File outFile, Task[] tasks, uint indent) {
	foreach (ref Task t; tasks) {
		outFile.writeTabs(indent);
		outFile.writefln("- %s", t.summary);

		if(t.priority) {	
			outFile.writeTabs(indent + 1);
			outFile.writefln("@ %d", t.priority);
		}

		string[] notes = t.notes.split("\n");
		foreach(string n; notes) {
			outFile.writeTabs(indent + 1);
			outFile.writefln("/ %s", n);
		}

		if (t.tags.length) {	
			outFile.writeTabs(indent + 1);
			outFile.writefln("# %s", t.tags.join("; "));
		}

		writeTasks(outFile, t.subTasks, indent + 1);
	}
}

void writeTabs(ref File outFile, uint tabs) {
	for(uint i = 0; i < tabs; i++) {
		outFile.write("\t");
	}
}