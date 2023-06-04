# Waiting-on-Inform
A text parser that can run code in godot based on inform 7 text patterns encased in brackets. This is intended to help port inform 7 code into godot when the inform 7 project uses embedded code. It may also be used if there is a desire to use at least some of inform 7's embedded code syntax. Feature development is ongoing. 

Note: The intended use case for this code is to parse one or two paragraphs of embedded code at a time. Currently, this is an expensive process, so I don't recommend using it to parse pages of text at a time. Consider parsing text while waiting on player input or similar strategies if the amount of embedded code that needs parsing is substantial. Most normal sized paragraphs should parse quickly enough, but I've included a function called measure_time_for() that can be used to measure the time in ms for callables run through it so you can get an idea of how much text produces a noticable delay. 

This text parser cannot parse the equivelent of inform 7 definitions. ([player is warrior], for example). I can't yet figure out good way to mimic it without substantial effort. This might change in the future. 

The parser will rely on you populating a dictionary of objects with their key values being their name in string format. This is how parser becomes aware of objects and can look them up by name, allowing things like [if health of player <= 0] to be evaluated properly. 

