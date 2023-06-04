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

##Authors Notes:
##This code is intended to process one or two paragraphs of text at a time. It
##should not be expected to perform quickly when given pages of text with embedded code
## at a time, and will likely produce a noticable delay. That does not mean I won't 
##be improving on it's performance, since there are always other things a program 
##needs to do than simply parsing text, but I don't recommend planning on using 
##it for that purpose. Benchmark first. 



#=========test functions===========
func testing():
	print("tested")


func boolean_true()->bool:
	return true


func boolean_false()->bool:
	return false

var boolean: bool = true

#=========test functions===========

## this is a cache of objects in format <object name> : <object>. The parser will look in this cache for any objects referenced in embedded code, so make sure it is populated with the relevant objects you expect to be referenced before embedded code is parsed. 
var registered_objects: Dictionary = {
	"Player" : self,
	"player" : self,
	"Player in lower case": self
	}


func _ready() -> void:
	compile_regex()
	var text = "This is text testing [testing]and then there is [if boolean]one[if boolean true] and two[end if][else]three[end if]. Also, there is [if boolean false]one[else if boolean false]two[else]three[end if]."
	#var test_text = " test text "
	measure_time_for(self.trigger, [text])

func compile_regex():
	#regex_spaces.compile(space_pattern)
	pass

##measures the time a function call takes in ms and prints it to the console.
func measure_time_for(callable: Callable, parameters: Array = []):
	var time_before:float = Time.get_unix_time_from_system()
	callable.callv(parameters)
	var time_after:float	= Time.get_unix_time_from_system()
	var total_time:float	= (time_after - time_before)*1000
	print("Time taken: " + str(total_time).substr(0, 6) + " ms")


func trigger(text):
	printerr(reconstruct_from_embedded_code(text, self))


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
		var variable = caller.get(snake_case(embedded_code))
		if is_valid_function_name(embedded_function) and caller.has_method(embedded_function):
		
			var _return_value = caller.call(embedded_function)
			if _return_value != null && typeof(_return_value) == TYPE_STRING:
				construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT, _return_value)
			else:
				construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT, "")
			continue
		elif variable != null:
			construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT, variable as String)
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
					variable = variable_check(caller, embedded_code)
					if variable == null:
						construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT)
					else:
						construct_text_segment(text_0_reconstruction_1, embedded_code_end, chop_methods.CHOP_RIGHT, str(variable))
					#[testin]and then there is [if boolean true]one[if boolean true] and two[end if][else]three[end if]. Also, there is [if boolean false]one[else if boolean false]two[else]three[end if].
	
	if waiting_on_error_insertion:
		var insertion_adjustment: int = 0
		for insertion_point in error_strings.keys():
			text_0_reconstruction_1[1] = text_0_reconstruction_1[1].insert(insertion_point + insertion_adjustment, " (:" + error_strings[insertion_point]+ ":) ")
			insertion_adjustment += error_strings[insertion_point].length() + 1
		
		waiting_on_error_insertion = false
		error_strings.clear()
		
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
	else: #embedded code is not a function contained in the caller and is likely a composition of variables and/or comparisons
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
			var result:bool = evaluate_comparison(caller, embedded_code, text_0_reconstruction_1[1].length())
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
				if index == operator_array[-1]: #last operator, so the next comparison must also be appended
					or_comparisons.append(comparisons[index+1])
				continue
				
			else:
				last_operator_was_and = true
				
				if and_collapsing:
					continue
			
			var left_evaluation: bool
			var right_evaluation:bool
			
			left_evaluation	= evaluate_comparison(caller, comparisons[index-1], text_0_reconstruction_1[1].length())
			
			if left_evaluation:
				#decide whether or not to evaluate the right comparison
				if index == operator_array[-1]: #last operator
					right_evaluation = evaluate_comparison(caller, comparisons[index+1], text_0_reconstruction_1[1].length())
					if right_evaluation:
						or_comparisons.append(true)
					else:
						or_comparisons.append(false)
					continue
				
				if  comparisons[index+2] != " and ": #and operators are grouped together
					right_evaluation = evaluate_comparison(caller, comparisons[index+1], text_0_reconstruction_1[1].length())
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
				result = evaluate_comparison(caller, comparison, text_0_reconstruction_1[1].length())
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



func evaluate_comparison(caller, comparison: String, comparison_index_end: int = 0)->bool:
	#first check if the comparison as a whole matches either a function or a variable.
	var results = function_variable_check(caller, comparison)
	
	if typeof(results) == TYPE_BOOL:
		return results
		
	
	#split the comparison into two segments at the comparison operator and process each 
	var operator_index: int		= -1
	var operator_length: int	= 0
	
	var pivot_value: int			= 0
	while operator_index < 0:
		pivot_value +=1
		var operator: String
		match pivot_value:
			1:
				operator = " <"
			2:
				operator = " >"
			3:
				operator = " is "
			4:
				operator = " ="
			5:
				operator = " !"
			_:#this means there is no operator and the measures at the beginning failed to return because no object, method, or variable could be found. or the operator wasn't spaced correctly
				insert_error(comparison_index_end, "Error: could not find reference match for comparison in embeded code: \"" + comparison + "\" Check comparison operator spacing")
				return true
		
		operator_index = comparison.find(operator)
		if operator_index >= 0:
			operator_length = operator.length() + 1
			var comparison_substr: String = comparison.substr(operator_index, 3)
			if comparison_substr == " is":
				if comparison.substr(operator_index, 8) == " is not ":
					operator_length += 3
				else:
					operator_length -= 1
			elif comparison_substr == " <=" or comparison_substr == " <=" or comparison_substr == " !=":
				operator_length += 1
			
			
	
	#split the comparison into two segments at the operator index
	var segment_one: String =  comparison.substr(0, operator_index)
	var segment_two: String = comparison.substr(operator_index + operator_length)
	
	#check each segment in case it is a function or variable
	var segment_one_results = function_variable_check(caller, segment_one)
	if segment_one_results == null:
		insert_error(comparison_index_end, "Error: could not find what embedded code was referencing, or the value of the reference was null for: " + segment_one + " Reminder, null values are not supported.")
		return true
	var segment_two_results = function_variable_check(caller, segment_two)
	if segment_two_results == null:
		insert_error(comparison_index_end, "Error: could not find what embedded code was referencing, or the value of the reference was null for: " + segment_two + " Reminder, null values are not supported.")
		return true
	
	match comparison.substr(operator_index, operator_length):
		" > ":
			match typeof(segment_one_results):
				TYPE_BOOL:
					#SYNTAX error
					insert_error(0, "Error: > operator does not support booleans")
				TYPE_INT:
					if typeof(segment_two_results) == TYPE_INT:
						return segment_one_results > segment_two_results
					else:
						#syntax error
						insert_error(0, "Error: comparisons being equated must be of same type")
		" < ":
			match typeof(segment_one_results):
				TYPE_BOOL:
					#SYNTAX error
					insert_error(0, "Error: < operator does not support booleans")
				TYPE_INT:
					if typeof(segment_two_results) == TYPE_INT:
						return segment_one_results < segment_two_results
					else:
						#syntax error
						insert_error(0, "Error: comparisons being equated must be of same type")
		" <= ":
			match typeof(segment_one_results):
				TYPE_BOOL:
					#SYNTAX error
					insert_error(0, "Error: <= operator does not support booleans")
				TYPE_INT:
					if typeof(segment_two_results) == TYPE_INT:
						return segment_one_results <= segment_two_results
					else:
						#syntax error
						insert_error(0, "Error: comparisons being equated must be of same type")
		" >= ":
			match typeof(segment_one_results):
				TYPE_BOOL:
					#SYNTAX error
					insert_error(0, "Error: >= operator does not support booleans")
				TYPE_INT:
					if typeof(segment_two_results) == TYPE_INT:
						return segment_one_results >= segment_two_results
					else:
						insert_error(0, "Error: comparisons being equated must be of same type")
						
		" is ":
			return equivilency_logic(segment_one_results, segment_two_results)
		" is not ":
			return !equivilency_logic(segment_one_results, segment_two_results)
		" = ":
			return equivilency_logic(segment_one_results, segment_two_results)
		
	
	return true

func equivilency_logic(segment_one_results, segment_two_results)->bool:
	if typeof(segment_one_results) == typeof(segment_two_results):
		return segment_one_results == segment_two_results
	else:
		#syntax error
		insert_error(0, "Error: comparisons being equated must be of same type")
		pass
	return true


##will check if the text comparison references a function or variable and returns the result. The function returns null if it is neither a function nor a variable. 
func function_variable_check(caller, comparison: String):
	if comparison.to_lower() == "false":
		return false
	elif comparison.to_lower() == "true":
		return true
	
	if !comparison.contains("<") and !comparison.contains(">"):
		#comparison is a possible, but not verified standalone function or variable
		var embedded_function: String = snake_case(comparison)
		
		if is_valid_function_name(embedded_function) and caller.has_method(embedded_function):
			var _return_value = caller.call(embedded_function)
			if _return_value != null:
				return _return_value
		
		var result = variable_check(caller, comparison)
		return result
		#just because we find a matching function doesn't mean it's an intended reference. If return value is not a bool, we assume it may be a name collision with a "variable of object" format
		
		
	return null

func variable_check(caller, comparison: String):
	if comparison.is_valid_int():
		return comparison.to_int()
	var comparison_snake = snake_case(comparison)
	var variable = caller.get(comparison_snake)
	var of_index: = comparison.find(" of ") 
	if variable != null:
		return variable
	
	elif of_index != -1:
		#split the comparison into segments at the of_index
		var variable_name = snake_case(comparison.substr(0, of_index))
		var object_name = comparison.substr(of_index + 4) #warning: this will be sensative to accidental double spaces. 
		var object = find_object_by_name(object_name)
		if object == null:
			return null
		else:
			return object.get(variable_name)
	else:
		#triggers for case where "<object> is/is not <variable/state>"
		return find_object_by_name(comparison)
	return null


var waiting_on_error_insertion: bool = false
var error_strings: Dictionary
##will add an error to a queue to be later concatonated to the output string reconstruction at the specified insertion point. 
func insert_error(insertion_point: int, error_message: String):
	waiting_on_error_insertion = true
	
	while error_strings.has(insertion_point):
		insertion_point += 1
	
	error_strings[insertion_point] = error_message


##searches a list of registered objects. the process is encapsulated here for convienience and ease of edit. 
func find_object_by_name(object_name: String)->Object:
	if registered_objects.has(object_name):
		return registered_objects[object_name]
	return null
	



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
	



func snake_case(text: String)->String:
		text = text.strip_edges()
		text = text.replace(" ", "_")
		return text

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
	string = snake_case(string)
	return string
