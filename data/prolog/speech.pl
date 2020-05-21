
:- module(speech, [say/3]).

say(exist(X)) --> [there, is, X].

say(question(exist(X))) --> [is, there, X].