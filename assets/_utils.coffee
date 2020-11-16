###*
 * Common core from "core-ui"
###

# Logger
Core=
	fatalError: console.error.bind console, 'FATAL-ERROR'

# OBJECT
_assign= Object.assign
_isArray= Array.isArray

# Get base URL
_getBaseURL= ->
	try
		baseURL= document.getElementsByTagName('base')[0].href
	catch error
		baseURL= document.location.href
	# fix base URL
	baseURL= new URL baseURL
	baseURL= baseURL.origin + baseURL.pathname.replace(/[^\/]+$/, '')
	return baseURL

# Run document on load
_runOnLoad= (fn)->
	if document.readyState is 'complete'
		fn()
	else
		window.addEventListener 'load', fn, {passive:yes, once: yes}
	return
