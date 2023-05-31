#MIT License
#
#Copyright (c) [year] [fullname]
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

extends Node


#test functions
func testing():
	print("tested")


func boolean_true()->bool:
	return true


func boolean_false()->bool:
	return false


func _ready() -> void:
	var text = "This is text testing [testing]and then there is [if boolean]one[if boolean true] and two[end if][else]three[end if]. Also, there is [if boolean false]one[else if boolean false]two[else]three[end if]."
	
	print(reconstruct_from_embedded_code(text, self))



func is_valid_function_name(text: String) -> bool:
	if text.is_empty():
		return false
	if !(text[0] == "_" or (text[0] <= "0" and text[0] >= "9") or (text[0] >= "a" and text[0] <= "z") or (text[0] >= "A" and text[0] <= "Z")):
		return false
	for i in range(1, text.length()):
		if !(text[i] == "_" or (text[i] >= "0" and text[i] <= "9") or (text[i] >= "a" and text[i] <= "z") or (text[i] >= "A" and text[i] <= "Z")):
			return false
	return true


#the idea is to use recursion to gradually chop the left hand side of the paragraph off, move it to text_reconstruction, and introduce logic inbetween the process based on embedded code. 
##This recieves a text paragraph from a say command, and searches it for embedded code, runs it, then reconstructs the text paragraph and returns it so it can be properly displayed to the player. 
func reconstruct_from_embedded_code(text: String, caller: Object, text_reconstruction: String = ""):
	var text_not_constructed: bool = true
	var text_0_reconstruction_1: Array = [text, text_reconstruction]
	
	while text_not_constructed:
		if text_0_reconstruction_1[0].is_empty():
			break
		
		var embedded_code_begin: int = text_0_reconstruction_1[0].find("[") #consider a specialized find that checks a specified range or emits an error when detecting embedded brackets. 
		if embedded_code_begin <= -1:							#no embedded code, so break
			text_0_reconstruction_1[1] += text_0_reconstruction_1[0]
			break
		
		var embedded_code_end = text_0_reconstruction_1[0].find("]") 
		if embedded_code_begin > embedded_code_end:
			if embedded_code_end >0:	
				construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT)
			text_0_reconstruction_1[1] += " Error: forgotten left bracket "
			break
			
		var next_left_bracket = text_0_reconstruction_1[0].find("[", embedded_code_begin+1)
		if next_left_bracket < embedded_code_end and next_left_bracket != -1: #needs work for nested code
			text_0_reconstruction_1[1] += " Error: forgotten right bracket "
			break
		
		if embedded_code_begin >0:	
			construct_text_segment(text_0_reconstruction_1, embedded_code_begin, chop_methods.CHOP_LEFT)
			embedded_code_end-= embedded_code_begin
			embedded_code_begin = 0 #i'm using a variable for code clarity, but it should always be 0
		
		
		if embedded_code_end == -1:
			#throw error, the writer forgot a bracket
			text_0_reconstruction_1[1] += text
			break
		
		var embedded_code: String = text_0_reconstruction_1[0].substr(embedded_code_begin+1, embedded_code_end-1) #embedded_code_end not included
		
		if is_bbcode(embedded_code):
			text_0_reconstruction_1[1] += trim_right(text_0_reconstruction_1[0], embedded_code_end+1) #keep the brackets for bbcode
			text_0_reconstruction_1[0] = trim_left(text_0_reconstruction_1[0], embedded_code_end) #removes the ] character
			continue
		
		#if the embedded code is a function name, call it regardless of contents of the text
		var embedded_function: String = to_function(embedded_code)
		if is_valid_function_name(embedded_function):
			if caller.has_method(embedded_function):
				var _return_value = caller.call(embedded_function)
				if _return_value != null && typeof(_return_value) == TYPE_STRING:
					construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT, _return_value)
				else:
					construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT, "")
				continue
		
		match embedded_code:
			"else":#misplaced else statement. 
				text_0_reconstruction_1[1] += " Error: misplaced if or else statement "
				#throw error, if there is an 'end if', skip to it. if there isn't, keep everything in and continue
				break
			"end if":
				#probably a nested if. check that if_results has a value, and that it is 
				construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT)
				break
			"one of":
				#start a list, remember the start
				break
			"or":
				break
				#check that a list exists, then add to it or call an error
			"at random":
				break
				#check if a list exists, and if it does then return a random element then clear the list
			_:
				if embedded_code.begins_with("else if ") && embedded_code.length() >8: #error: code block must retain '[' before calling _process_if_statement()
					embedded_code = embedded_code.substr(8)
					_process_if_statement(text_0_reconstruction_1, embedded_code, embedded_code_end, caller)
				elif embedded_code.begins_with("if "):
					embedded_code = embedded_code.substr(3)
					_process_if_statement(text_0_reconstruction_1, embedded_code, embedded_code_end, caller)
				else:
					construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT)
					#[testin]and then there is [if boolean true]one[if boolean true] and two[end if][else]three[end if]. Also, there is [if boolean false]one[else if boolean false]two[else]three[end if].
	return text_0_reconstruction_1[1]


#to construct this properly, We want to call this recursively, but only if the if statement evaluated as true contains an if statement. 
func _process_if_statement(text_0_reconstruction_1: Array, embedded_code: String, embedded_code_end: int, caller):
	#first, check to see if the embedded code is just an outright function
	var embedded_function: String = to_function(embedded_code)
	if is_valid_function_name(embedded_function) && caller.has_method(embedded_function):
		var _return_value = caller.call(embedded_function)
		if _return_value != null && typeof(_return_value) == TYPE_BOOL:
			if _return_value:
				_process_if_success(text_0_reconstruction_1, embedded_code, embedded_code_end, caller)
				return
				
			else:#return value of function is false
				_process_if_failure(text_0_reconstruction_1, embedded_code, embedded_code_end, caller)
				
		else: #function call contained no bool value, throw error
			return
	else: #embedded code is not a function contained in the caller and is likely a composition of variables and/or comparisons.
#		var quadruple_comparison_pattern= "(^[\\s\\w><=!.]*)(?: or |\\|\\|| and | && )([\\s\\w><=!.]*)(?: or |\\|\\|| and | && )([\\s\\w><=!.]*)(?: or |\\|\\|| and | && )([\\s\\w><=!.]*)$"
#		var triple_comparison_pattern	= "(^[\\s\\w><=!.]*)(?: or |\\|\\|| and | && )([\\s\\w><=!.]*)(?: or |\\|\\|| and | && )([\\s\\w><=!.]*)$"
#		var double_comparison_pattern	= "(^[\\s\\w><=!.]*)(?: or |\\|\\|| and | && )([\\s\\w><=!.]*)$"
		var comparison_pattern			= " or | and | && | \\|\\| "
		
		var comparison_reg: RegEx		= RegEx.new()
		comparison_reg.compile(comparison_pattern)
		
		#find the number of comparisons in the embedded code
		var comparison_operators: Array = comparison_reg.search_all(embedded_code)
		
		#for every comparison operator, split the string at the oporator and append the string to the left into an array
		var comparisons: Array = [0] # The first element represents the sum of characters in all comparisons
		var embedded_code_0_comparisons_1	= [embedded_code, comparisons]
		if comparisons.size()==1:
			var result:bool = evaluate_comparison(embedded_code)
			if result:
				_process_if_success(text_0_reconstruction_1, embedded_code, embedded_code_end, caller)
				
			else:#return value of function is false
				_process_if_failure(text_0_reconstruction_1, embedded_code, embedded_code_end, caller)
			return
				
		for comparison_operator in comparison_operators:
			#remove and append the comparison before the oporator
			construct_text_segment(embedded_code_0_comparisons_1, comparison_operator.get_start() - comparisons[0], chop_methods.CHOP_LEFT)
			#remove and append the oporator
			construct_text_segment(embedded_code_0_comparisons_1, comparison_operator.get_end() - comparisons[0], chop_methods.CHOP_RIGHT, "")
		
		embedded_code_0_comparisons_1[1].append(embedded_code_0_comparisons_1[0])
		#comparisons should now look like [<total elements minus the last comparison>, <comparison string>, <operator>, comparison string]
		
#		var and_operator_indices = []
		#note: And operators must be compared first before or operators.
#		for index in range(2, comparisons.size(), 2):
#			if comparisons[index] == " and ":
#					and_operator_indices.append(index)
		
		var backup_comparisons:Array = comparisons.duplicate()
		var or_comparisons: Array	= []
		
		var last_operator_was_and: bool = false
		#the idea with and_collapsing is that all nieghboring 'and' operators rely on each others input for evaluation. so one is false, the others can be skipped. when an and evaluates false, and_collapsing is set to true and all subsequent 'and' operators will be skipped to false until an 'or' operator is encountered. if an 'or' is encountered without an 'and' evaluating to false, only then is the result added to or_comparisons. 
		var and_collapsing: bool = false
		var operator_array: Array = range(2 , comparisons.size(), 2)
		for index in operator_array:
			if comparisons[index] != " and ":
				if last_operator_was_and:
					last_operator_was_and = false
					
				or_comparisons.append(comparisons[index-1])
				if index == operator_array[-1]: #last operator, so th next comparison must also be appended
					or_comparisons.append(comparisons[index+1])
				continue
				
			else:
				last_operator_was_and = true
				
				if and_collapsing:
					continue
			
			var left_evaluation: bool
			var right_evaluation:bool
			
			left_evaluation	= evaluate_comparison(comparisons[index-1])
			
			if left_evaluation:
				#decide whether or not to evaluate the right comparison
				if index == operator_array[-1]: #last operator
					right_evaluation = evaluate_comparison(comparisons[index+1])
					if right_evaluation:
						or_comparisons.append(true)
					else:
						or_comparisons.append(false)
					continue
				
				if  comparisons[index+2] != " and ": #and operators are grouped together
					right_evaluation = evaluate_comparison(comparisons[index+1])
					if right_evaluation:
						or_comparisons.append(true)
					else:
						or_comparisons.append(false)
				continue
			else: #and is false, start collapsing and skip all preceding 'and' operators until an 'or' is encountered or the loop finishes. 
				and_collapsing = true
				or_comparisons.append(false)
				continue
		
		#the ands are now evaluated. evaluate or's contained in or_comparisons. 
		var final_result: bool = false
		for comparison in or_comparisons:
			if typeof(comparison) == TYPE_BOOL:
				if comparison:
					final_result = true
					break
			else:
				var result: bool
				result = evaluate_comparison(comparison)
				if result:
					final_result = true
					break
		
		#final_result should now contain the proper boolean result for the embedded if statement.


func _process_if_success(text_0_reconstruction_1: Array, embedded_code: String, embedded_code_end: int, caller):
	construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT, "")
	var processing_if: bool = true
	while processing_if:
		
		var embedded_code_begin 
		embedded_code_begin = text_0_reconstruction_1[0].find("[")
		if embedded_code_begin != 0:
			construct_text_segment(text_0_reconstruction_1, embedded_code_begin, chop_methods.CHOP_LEFT)
		embedded_code_begin = 0
	
		if text_0_reconstruction_1[0].begins_with("[if "):
			embedded_code_end = text_0_reconstruction_1[0].find("]")
			embedded_code = text_0_reconstruction_1[0].substr(embedded_code_begin+1, embedded_code_end-1) #since embedded code was discovered as function, it is no longer needed and can be overwritten
			embedded_code = embedded_code.substr(3)
			_process_if_statement(text_0_reconstruction_1, embedded_code, embedded_code_end, caller)
			continue
		elif text_0_reconstruction_1[0].begins_with("[end if]"):
			#find end if, construct and replace with empty string
			embedded_code_end = text_0_reconstruction_1[0].find("[end if]") + 7
			construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT, "")
			break
			
		elif text_0_reconstruction_1[0].begins_with("[else"):
			#skip to the proper end if
			var first_if	= text_0_reconstruction_1[0].find("[if ")
			var first_end_if = text_0_reconstruction_1[0].find("[end if]")
			var nested_if_exists: bool = false
			if first_if< first_end_if && first_if != -1:
				nested_if_exists = true
			
			if nested_if_exists:
				var end_if_not_found: bool = true
				while end_if_not_found:
					if first_if < first_end_if && first_if != -1:
						first_if = text_0_reconstruction_1[0].find("[if ", first_if+3)
						first_end_if = text_0_reconstruction_1[0].find("[end if]", first_end_if+7)
					else:
						end_if_not_found = false
						
			construct_text_segment(text_0_reconstruction_1, first_end_if+7, chop_methods.CHOP_RIGHT, "")
			break 
			
		else:
			text_0_reconstruction_1[1]+= "Error: unhandled exception in_process_if_statement()."
			break
		processing_if = false # A failsafe. used break and continue to specify flow. 


func _process_if_failure(text_0_reconstruction_1: Array, embedded_code: String, embedded_code_end: int, caller):
	construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT, "")
	#check if there is another if between the next end if.
	var first_if	= text_0_reconstruction_1[0].find("[if ")
	var first_end_if = text_0_reconstruction_1[0].find("[end if]")
	var nested_if_exists: bool = false
	if first_if< first_end_if && first_if != -1:
		nested_if_exists = true
	#find the next else or end if.
	
	var embedded_code_begin = text_0_reconstruction_1[0].find("[")
	var first_else: int
	if nested_if_exists:
		first_else = text_0_reconstruction_1[0].find("[else", first_end_if)
		first_end_if = text_0_reconstruction_1[0].find("[end if]", first_end_if+7)
	else:
		first_else = text_0_reconstruction_1[0].find("[else")
	if first_end_if == -1:
		#throw error, all ifs must have an end if
		return
	if first_else < first_end_if && first_else != -1: #an else block needs to be processed
		#throw away the previous if branch
		embedded_code_begin = first_else
		construct_text_segment(text_0_reconstruction_1, embedded_code_begin, chop_methods.CHOP_LEFT, "")
		#embedded_code_begin not set to 0 because it is used to correct first_end_if 
		
		if text_0_reconstruction_1[0].substr(0, 6) == "[else]":
			#progress to end of embedded else
			construct_text_segment(text_0_reconstruction_1, 5, chop_methods.CHOP_RIGHT, "")
			#progress to the end if, keeping the text
			construct_text_segment(text_0_reconstruction_1, first_end_if-embedded_code_begin-6, chop_methods.CHOP_LEFT)
			#remove end if
			construct_text_segment(text_0_reconstruction_1, 7, chop_methods.CHOP_RIGHT, "")
			return
		elif text_0_reconstruction_1[0].substr(0, 9) == "[else if ":
			#progress to end of else if, before the rest of embedded code
			#construct_text_segment(text_0_reconstruction_1, 8, chop_methods.CHOP_RIGHT, "")
			embedded_code_end = text_0_reconstruction_1[0].find("]")
			embedded_code = text_0_reconstruction_1[0].substr(9, embedded_code_end-9)
			_process_if_statement(text_0_reconstruction_1, embedded_code, embedded_code_end, caller)
			return
	else: #skip to end if
		construct_text_segment(text_0_reconstruction_1, first_end_if+7, chop_methods.CHOP_RIGHT, "")


func evaluate_comparison(comparison: String)->bool:
	return true
	
	
	
	
		#'is' or '='
		#'is not'
		#'of' or '.'
		#'or' or '||'
		#'and' or '&&'
		#'greater than' or '>'
		#'less than'or '<'
		#repeated operations until next ']'
					#if the result of the evaluation is false, skip the text to the next '[' and continue.
					#else substitute the text up until the end of the next [end if] and continue
					
						
						#yes
							#check if name of function in caller's script, then FS if caller not a member of FS
								#yes
									#run function, capture return value
									#if return value is not null, and is a string, add string to text_reconstruction, return. 
						#no
							
						
					#check if not containing "of"
						#yes
							#fetch string before and after "of", make sure after is inbetween "of" and comparison symbols
							#return if either is blank
							#check if after is a variable in the script, return if not
							#check if before is a member variable of after, return if not
						#no
							#check for comparison symbols



enum chop_methods {CHOP_LEFT, CHOP_RIGHT}
##concatonates the the string to the left of the index to the reconstruction and chops it off the text. if code_substitution is set to a value it replaces the text to the left of the index when concatonating to the reconstruction.
##this function is obtuse and confusing, it really needs to be worked on
func construct_text_segment(text_0_reconstruction_1: Array, index:int, recon_method: chop_methods,  code_substitution: String = "keep_chopped_code"):
	
	if code_substitution == "keep_chopped_code":
		
		match recon_method:
			chop_methods.CHOP_LEFT:
				
				if typeof(text_0_reconstruction_1[1]) == TYPE_ARRAY:
					var substring: String = trim_right(text_0_reconstruction_1[0], index)
					text_0_reconstruction_1[1].append(substring)
					text_0_reconstruction_1[1][0] += substring.length()
					
				else:
					text_0_reconstruction_1[1] += trim_right(text_0_reconstruction_1[0], index) #removes the character at the index
			
			chop_methods.CHOP_RIGHT:
				
				if typeof(text_0_reconstruction_1[1]) == TYPE_ARRAY:
					var substring: String = trim_right(text_0_reconstruction_1[0], index+1)
					text_0_reconstruction_1[1].append(substring)
					text_0_reconstruction_1[1][0] += substring.length()
					
					
				else:
					text_0_reconstruction_1[1] += trim_right(text_0_reconstruction_1[0], index+1) #keeps the character at the index
	else:
		
		if typeof(text_0_reconstruction_1[1]) == TYPE_ARRAY:
			#only runs when an unwanted delimeter is in the source text. must keep track of characters about to be removed.
			match chop_methods:
				chop_methods.CHOP_LEFT:
					text_0_reconstruction_1[1][0] += trim_right(text_0_reconstruction_1[0], index).length()
				chop_methods.CHOP_RIGHT:
					text_0_reconstruction_1[1][0] += trim_right(text_0_reconstruction_1[0], index+1).length()
		else:
			text_0_reconstruction_1[1] += code_substitution
	
	match recon_method:
		chop_methods.CHOP_LEFT:
			if typeof(text_0_reconstruction_1[1]) == TYPE_ARRAY:
				var substring: String = trim_right(text_0_reconstruction_1[0], index)
				text_0_reconstruction_1[1].append(substring)
				text_0_reconstruction_1[1][0] += substring.length()
				
			text_0_reconstruction_1[0] = trim_left(text_0_reconstruction_1[0], index) #keeps the character at the index
		
		chop_methods.CHOP_RIGHT:
			if typeof(text_0_reconstruction_1[1]) == TYPE_ARRAY:
				var substring: String = trim_right(text_0_reconstruction_1[0], index+1)
				text_0_reconstruction_1[1].append(substring)
				text_0_reconstruction_1[1][0] += substring.length()
			text_0_reconstruction_1[0] = trim_left(text_0_reconstruction_1[0], index+1) #removes the character at the index
	
	


func is_bbcode(embedded_code:String)->bool:
	return false


##chops off the left hand side of a string at the specified index and returns the rest. index is not included in return value
func trim_left(text:String, index:int)->String:
	var x = text.right(index-index*2)
	return x
##chops off the right hand side of a string at the specified index and returns the rest. index is not included in return value 
func trim_right(text:String, index:int)->String:
	var x= text.left(index)
	return x

func to_function(string: String)->String:
	string = string.to_lower()
	string = string.to_snake_case()
	return string
