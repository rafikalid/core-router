###*
 * Router
###
<% var Core= false; %>
do->
	"use strict"
	#=include _utils.coffee
	#=include router/_main.coffee

	# Export interface
	if module? then module.exports= Router
	else if window? then window.Router= Router
	else
		throw new Error "Unsupported environement"
	return
