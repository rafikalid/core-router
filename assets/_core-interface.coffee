###*
 * ROUTER
###
goto: (utl)->
	document.location= url
	this # chain
defaultRouter: null
###*
 * ROUTER
 * @optional @param {Boolean} options.caseSensitive - if path is case sensitive @default false
 * @optional @param {Boolean} options.ignoreTrailingSlash - ignore trailing slash @default true
 * @optional @param {Number} options.cacheMax - cache max entries @default 50
 * @optional @param {Number} options.maxLoops - Lookup max loop to prevent infinit loops @default 1000
 * @optional @param {function} options.out - called when quiting page
 * @optional @param {function} options.catch - called when error happend: Example: {code:404}
 * @optional @param {Boolean} options.run - run router when page loaded, @default true
###
Router: do ->
	#=include router/_main.coffee
	return Router
