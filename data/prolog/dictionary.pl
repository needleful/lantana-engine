module(dictionary,
	[
		verb/1,
		past/3
	]).

verb(abandon).
verb(abduct).
verb(abhor).
verb(abort).
verb(absorb).
verb(abstain).
verb(abuse).
verb(accommodate).
verb(accompany).
verb(accomplish).
verb(account).
verb(accrue).
verb(accumulate).
verb(ace).
verb(ache).
verb(achieve).
verb(acknowledge).
verb(acquaint).
verb(acquire).
verb(act).
verb(adapt).
verb(add).
verb(adjust).
verb('ad lib').
verb(admit).
verb(adopt).
verb(affect).
verb(age).
verb(agonize).
verb(agree).
verb(aid).
verb(alarm).
verb(alert).
verb(allow).
verb(allude).
verb(alter).
verb(amass).
verb(amaze).
verb(ambush).
verb(amend).
verb(amuse).
verb(analyse).
verb(anger).
verb(annihilate).
verb(announce).
verb(annoy).
verb(answer).
verb(antagonise).
verb(appal).
verb(appeal).
verb(appear).
verb(appease).
verb(appoint).
verb(appraise).
verb(appreciate).
verb(approve).
verb(ask).
verb(assault).
verb(assert).
verb(assess).
verb(assist).
verb(assume).
verb(attach).
verb(attack).
verb(attempt).
verb(attend).
verb(author).
verb(avoid).
verb(await).
verb(awake).

verb(babble).
verb(bail).
verb(bake).
verb(balance).
verb(balk).
verb(ban).
verb(bang).
verb(barge).
verb(base).
verb(beam).

verb(kill).


past(abhor, abhorred).
past('ad lib', 'ad libbed').
past(admit, admitted).
past(appal, appalled).
past(ban, banned).
past(read, read).
past(say, said).

past(awake, awoke, awoken).
past(drink, drank, drunk).
past(eat, ate, eaten).

past(Present, Past, Participle) :-
	past(Present, Past);
	(	verb(Present),
		(	(	atom_chars(Present, Chars),
				append(_, [e], Chars),
				atom_concat(Present, d, Past),
				!
			);
			atom_concat(Present, ed, Past)
		)
	), 
	Participle=Past.