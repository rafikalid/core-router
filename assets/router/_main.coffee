###*
 * DEFAULT OPTIONS
###
#=include _utils.coffee
#=include _const.coffee

###* Create route node ###
_createRouteNode= ->
	parent:		null # Parent node
	# metadata
	route:		null
	param:		null
	path:		null
	# Controller
	get:		null
	wrappers:	null
	# index
	static:		{}
	params:		null
	wildcards:	null
	wildcard:	null
###* Resolve or create node inside array ###
_resolveNodeInArray= (paramName, param, arr, upsert)->
	paramRegex= param.regex
	len= arr.length
	i= 0
	while i < len
		return arr[i+2] if arr[i+1] is paramName
		i+= 3
	if upsert
		node= do _createRouteNode
		node.param= paramName
		arr.push paramRegex, paramName, node
	return node
###*
 * TREE
 * NODE:
 * 		├─ get ---
 * 		├─ wrappers: [wrapper1, ...]
 * 		├─ static
 * 		│	├─ node1: NODE
 * 		│	└─ node2: NODE
 * 		├─ params: [/regex/, NODE, ...]
 * 		├─ wildCards: [/regex/, NODE, ...]
 * 		└─ wildcard: NODE
###
###*
 * Base path interface
 * Enables to group path declarations
###
class BasePath
	constructor: (router, basePATH)->
		@_router= router
		@_currentNodes= router._loadRoute basePATH, router._tree
		return
	# Get
	get: (route, node)->
		throw new Error 'Illegal arguments' unless arguments.length is 2
		# Add
		router= @_router
		if _isArray route
			for r,i in route
				router._get r, node, i, @_currentNodes
		else
			router._get route, node, 0, @_currentNodes
		this # chain
###*
 * ROUTER
###
ID_GEN= 0 # Generate unique id for each create router
class Router
	constructor: (options)->
		@ctx= null # Current active context
		# Options
		@_options= options= _assign {}, DEFAULT_OPTIONS, options
		# PARAMS
		@_params= {}
		@_staticParams= {}
		# Router tree
		treeNode= @_tree= _createRouteNode()
		treeNode.route= '/'
		treeNode.path= [treeNode]
		treeNode.static['']= treeNode
		# Base route
		@_baseURL= _getBaseURL()
		@_basePATH= new URL(@_baseURL).pathname
		# metadata
		@_node= null # current node
		@node= null
		# URL
		@referrer= @location= if document.referrer then new URL document.referrer else null
		# Router id, used when calling ajax
		@id= 'rtr-' + (ID_GEN++) # Router id
		# Cache
		<% if(Core){ %>
		@_cache= new Core.LRU_TTL(max: @_options.cacheMax)
		<% } else { %>
		console.warn("""
			Router>> To get those fonctionnalities. use \"core-ui\" instead:
				- LRU_TTL cache is missing
				- Could not cancel your ajax calls, you need to do it yourself.
				- No logger service
			""")
		<%} %>
		# Enable call @_back for fisrt time loaded
		history.pushState {isRoot: yes}, '', @location.href
		# prevent back and do an other action like closing popups
		@_back= []
		# Pop state
		_popstateListener= (event)=>
			# call callbacks
			backCb= @_back
			state= event.state
			if cb= backCb.pop()
				try
					history.pushState state, '', @location.href
					cb state
				catch err
					Core.fatalError 'Router', err
			# If first page
			else if state and state.isRoot
				history.back() # quit root page
			# GOTO
			else
				path= state?.path or document.location
				@goto path, HISTORY_BACK
			return
		window.addEventListener 'popstate', _popstateListener, off
		# start router
		if options.run
			_runOnLoad => @goto document.location.href, ROUTER_ROOT_PATH
		# Default operations
		<% if(Core){ %>
		unless Core.defaultRouter
			Core.defaultRouter= this
			Core.goto= @goto.bind this
		<% } %>
		return

	###*
	 * Add param
	 * @param {String, Array[String]} paramName - Name of the path or query parameter
	 * @optional @param {RegExp, Function} regex - Check the param value
	 * @optional @param {Function} convert - convert param value (async)
	###
	param: (paramName, regex, convert)->
		try
			# Check param name
			if _isArray paramName
				@param(el, regex, convert) for el in paramName
				return this # chain
			else unless typeof paramName is 'string'
				throw 'Illegal param name'
			throw "Illegal param name: #{paramName}" if paramName is '__proto__'
			throw "Param '#{paramName}' already set" if @_params[paramName]
			# Prepare arguments
			if typeof regex is 'function'
				regex= test: regex
			else if regex?
				throw 'Invalid 2nd arg' unless regex instanceof RegExp
			else regex= PARAM_DEFAULT_REGEX
			# convert
			if convert?
				throw 'Invalid 3rd arg' unless typeof convert is 'function'
			else convert= PARAM_DEFAULT_CONVERTER
			# Add
			@_params[paramName]=
				regex: regex
				convert: convert
		catch err
			err= new Error "ROUTER.param>> #{err}" if typeof err is 'string'
			throw err
		this # chain
	###* static params ###
	staticParam: (paramName, values)->
		try
			# Check args
			throw "Illegal argumets" unless arguments.length is 2 and _isArray values
			throw "Expected String array" for el in values when typeof el isnt 'string'
			throw new Error "Illegal param name: #{paramName}" if paramName is '__proto__'
			throw new Error "ROUTER.staticParam>> Param '#{paramName}' already set" if @_params[paramName]
			@_staticParams[paramName]= values
			@_params[paramName]=
				regex: PARAM_DEFAULT_REGEX
				convert: PARAM_DEFAULT_CONVERTER
		catch error
			error= new Error "ROUTER.staticParam>> #{error}" if typeof error is 'string'
			throw error
		this # chain
	###*
	 * Wrap route
	###
	wrap: (route, wrapper)->
		throw new Error 'Illegal arguments' unless arguments.length is 2 and typeof route is 'string' and typeof wrapper is 'function'
		nodes= @_loadRoute(route, @_tree)
		(node.wrappers?= []).push wrapper for node in nodes
		this # chain
	###*
	 * Base Path
	###
	route: (path)-> new BasePath this, path
	###*
	 * GET
	###
	get: (route, node)->
		throw new Error 'Illegal arguments' unless arguments.length is 2
		# Add
		if _isArray route
			for r,i in route
				@_get r, node, i, @_tree
		else
			@_get route, node, 0, @_tree
		this # chain
	_get: (route, node, routeIndex, currentNodes)->
		# Checks
		throw new Error "Route expected string" unless typeof route is 'string'
		if typeof node is 'function'
			node= {in: node}
		else if typeof node is 'object' and node
			node= _assign {}, node
		else
			throw "Second arg expected function or object"
		# Add route
		routeNodes= @_loadRoute(route, currentNodes)
		for routeNode in routeNodes
			throw new Error "Route already set: #{route}" if routeNode.get?
			node.route?= route
			node.routeIndex= routeIndex
			routeNode.get= node
		return
	###*
	 * Goto
	###
	goto: (url, doState)->
		try
			# convert URL
			url= (new URL url, @_baseURL) unless url instanceof URL
			# previous
			previousNode= @_node
			if previousLocation= @location
				previousPath= previousLocation.pathname
				@referrer= previousLocation
			# create context
			path=		url.pathname
			@location=	url
			@href=	url.href
			jsonURL= new URL(url)
			jsonURL.searchParams.set 'type', 'json'
			@ctx= ctx=
				isRoot:			doState is ROUTER_ROOT_PATH
				url:			url
				path:			path
				jsonPath:		jsonURL.href # Shortcut to call json api
				isHistoryBack:	doState is HISTORY_BACK # if this is fired by history.back
				isNew:			(doState is ROUTER_ROOT_PATH) or (doState is ROUTER_RELOAD) or (path isnt previousPath)
				isReload:		doState is ROUTER_RELOAD
				params:			{}	# Path params
				query:			{}	# Query params
				history:		path: url.href
				route:			null
				options:		null
				# referrer
				referrer:		@referrer
				referrerOptions: previousNode and previousNode.node
			# lookup for new Node
			<% if(Core){ %>
			unless result= @_cache.get path
				result= @_resolvePath path
				@_cache.set path, result
			<% } else { %>
			# Cache not enabled
			result= @_resolvePath path
			<%} %>
			# Continue
			@_node= result.node
			@node= result.node?.get
			throw result.error or {code: result.status} unless result.status is 200
			ctx.options= result.node
			ctx.route= result.route
			# Path params
			params= ctx.params
			paramMap= @_params
			i=0
			resp= result.params
			len= resp.length
			while i < len
				pName= resp[i++]
				params[pName]= await paramMap[pName].convert resp[i++]
			# Query params
			params= ctx.query
			url.searchParams.forEach (v, k)->
				# convert value
				v= await p.convert(v) if p= paramMap[k]
				# add
				if v2= params[k]
					if _isArray v2 then v2.push v
					else params[k]= [v2, v]
				else params[k]= v
			# call previous node out
			if previousNode and (previousNodeOptions= previousNode.node)
				previousNodeOptions= previousNodeOptions.get
				await previousNodeOptions.out? ctx
				await previousNodeOptions.outOnce? ctx if ctx.isNew
			# push in history
			urlHref= url.href
			if history?
				if doState is ROUTER_ROOT_PATH
					# history?.pushState (path:urlHref), '', urlHref
				else unless (doState is HISTORY_BACK) or (previousLocation and urlHref is previousLocation.href) # do not push if it's history back or same URL
					historyState= path: urlHref
					if doState is HISTORY_REPLACE
						history.replaceState historyState, '', urlHref
					else unless doState is HISTORY_NO_STATE
						history.pushState historyState, '', urlHref
			# call listeners
			if (wrappers= result.wrappers) and wrappers.length
				wrapperI= 0
				wrapperNext= =>
					if wrapperI < wrappers.length
						return wrappers[wrapperI++] ctx, wrapperNext
					else
						return @_gotoRun result, ctx
				await wrapperNext()
			else
				await @_gotoRun result, ctx
		catch err
			err= "ROUTER.goto>> #{err}" if typeof err is 'string'
			@_options.catch err, ctx
		this # chain
	_gotoRun: (result, ctx)->
		if nodeGet= result.node?.get
			if ctx.isNew
				# abort active xhr calls
				<% if(Core){ %>
				Core.ajax.abort @id
				<% } %>
				# toggle <html> classes
				if html= document.getElementsByTagName('html')[0]
					htmlClassList= html.classList
					# Remove previous classes
					if (referrerOptions= ctx.referrerOptions) and list= referrerOptions.toggleClasses
						throw new Error "toggleClasses expected Array" unless _isArray list
						htmlClassList.delete cl for cl in list
					# Add new Classes
					if list= nodeGet.toggleClasses
						throw new Error "toggleClasses expected Array" unless _isArray list
						htmlClassList.add cl for cl in list
				# Goto top
				scrollTo 0, 0 if nodeGet.scrollTop
				# Call current node in once
				await nodeGet.once? ctx
			# Call in
			await nodeGet.in? ctx
		return
	###*
	 * Push URL to history without executing GOTO
	###
	setURL: (url)->
		url= (new URL url, @_baseURL) unless url instanceof URL
		# push in history
		urlHref= url.href
		unless urlHref is @location.href
			@location= url
			history?.pushState {path: urlHref}, '', urlHref
		this # chain
	###*
	 * Restart the router
	###
	restart: ->
		<% if(Core){ %>
		Core.ajax.abort @id
		<% } %>
		@goto @location, ROUTER_ROOT_PATH
		return
	###*
	 * Reload
	###
	reload: (forced)->
		if forced
			@_options.out @location, true
		else
			@goto @location, ROUTER_RELOAD
		this # chain
	repaint: ->
		@goto @location
		this
	###*
	 * Replace
	###
	replace: (url)-> @goto url, HISTORY_REPLACE
	###*
	 * History back cb
	###
	back: ->
		if (url= @referrer) and url.href.startsWith @_baseURL
			history.back()
		else
			@goto ''
	###* Execute a callback when history.back instead of changing view ###
	whenBack: (cb)->
		throw new Error 'Expected 1 argument as function' unless arguments.length is 1 and typeof cb is 'function'
		@_back.push cb
		this # chain
	###*
	 * Load route
	###
	_loadRoute: (route, currentNodes)->
		throw "Illegal route: #{route}" if ROUTE_ILLEGAL_PATH_REGEX.test(route)
		# Convert to abs route
		path= route
		if currentNodes is @_tree
			path= @_basePATH + path unless path.startsWith '/'
			currentNodes= [currentNodes]
		else
			currentNodes= currentNodes.slice 0
		# Add
		settings= @_options
		isntCaseSensitive= not settings.caseSensitive
		parts= path.split '/'
		partsLen= parts.length
		paramSet= new Set() # check params are not repeated
		paramMap= @_params
		staticParamsMap= @_staticParams
		# Settings
		avoidTrailingSlash= !!settings.ignoreTrailingSlash
		# Go through tree
		currentNodes2= []
		for part,i in parts
			tmpC= currentNodes
			currentNodes= currentNodes2
			currentNodes2= tmpC
			currentNodes.length= 0
			# Resolve sub nodes
			for currentNode in currentNodes2
				# wild card
				if part is '*'
					throw "Illegal use of wildcard: #{route}" unless i+1 is partsLen
					unless node= currentNode.wildcard
						node= currentNode.wildcard= do _createRouteNode
						node.param= '*'
						node.type= ROUTER_WILDCARD_NODE
						node.parent= currentNode
					currentNodes.push node
				#  parametered wildcard
				else if part.startsWith '*'
					throw "Illegal use of wildcard: #{route}" unless i+1 is partsLen
					currentNode.wildcards?= []
					paramName= part.slice 1
					throw "Undefined parameter: #{paramName}" unless param= paramMap[paramName]
					node= _resolveNodeInArray paramName, param, currentNode.wildcards, yes
					node.type= ROUTER_WILDCARD_PARAM_NODE
					node.parent= currentNode
					currentNodes.push node
				# parametred node
				else if part.startsWith ':'
					paramName= part.slice 1
					# Static path param
					if param= staticParamsMap[paramName]
						for paramEl in param
							paramEl= paramEl.toLowerCase() if isntCaseSensitive
							unless node= currentNode.static[paramEl]
								node= currentNode.static[paramEl]= do _createRouteNode
								node.param= paramName
								node.type= ROUTER_STATIC_PARAM_NODE
								node.parent= currentNode
							currentNodes.push node
					# Path param
					else if param= paramMap[paramName]
						currentNode.params?= []
						node= _resolveNodeInArray paramName, param, currentNode.params, yes
						node.type= ROUTER_PARAM_NODE
						node.parent= currentNode
						currentNodes.push node
					else
						throw "Undefined parameter: #{paramName}"
				# static node
				else
					part= part.slice(1) if part.startsWith('?') # escaped static part
					part= part.toLowerCase() if isntCaseSensitive
					unless node= currentNode.static[part]
						node= currentNode.static[part]= do _createRouteNode
						node.type= ROUTER_STATIC_NODE
						node.parent= currentNode
					currentNodes.push node
			# Check params not repeated
			if vl= currentNodes[0].param
				throw "Repeated param [#{vl}] in route: #{path}" if paramSet.has vl
				paramSet.add vl
			# Finalize nodes
			for node in currentNodes
				# Avoid trailing slash and multiple slashes
				node.static['']= node if avoidTrailingSlash # Avoid trailing slash and multiple slashes
				# stack
				unless node.path
					nodePath= node.parent.path.slice(0)
					nodePath.push node
					node.path= nodePath
					node.route= parts.slice(0, i+1).join('/')
		return currentNodes
	###*
	 * Resolve path
	 * @return {Object} {status, node, wrappers:[], error, params:[] }
	###
	_resolvePath: (path)->
		try
			currentNode= @_tree
			paramMap= @_params
			settings= @_options
			path= path.toLowerCase() unless settings.caseSensitive
			# Result
			result=
				status:		404
				node:		null
				wrappers:	[]
				error:		null
				params:		[]
			# Non recursive alg
			parts= path.split '/'
			partsLen= parts.length
			maxLoops= settings.maxLoops
			maxLoopsI= 0 # Inc is faster than dec
			nodeStack= [currentNode]
			metadataStack= [0, 0, 0] # [NodeType(0:static)]
			while nodeStack.length
				# prevent server freez
				throw new Error "Router>> Seeking exceeds #{maxLoops}" if ++maxLoopsI > maxLoops
				# Load ata
				currentNode= nodeStack.pop()
				# metadata
				dept=		metadataStack.pop()
				nodeType=	metadataStack.pop()
				nodeIndex=	metadataStack.pop()
				# path part
				part= parts[dept]
				# switch nodetype
				switch nodeType
					when ROUTER_STATIC_NODE, ROUTER_STATIC_PARAM_NODE # Static
						# add alts
						if currentNode.wildcard
							nodeStack.push currentNode
							metadataStack.push 0, ROUTER_WILDCARD_NODE, dept
						if currentNode.wildcards
							nodeStack.push currentNode
							metadataStack.push 0, ROUTER_WILDCARD_PARAM_NODE, dept
						if currentNode.params
							nodeStack.push currentNode
							metadataStack.push 0, ROUTER_PARAM_NODE, dept
						# check for static node
						if node= currentNode.static[part]
							currentNode= node
							++dept
							if dept < partsLen
								nodeStack.push currentNode
								metadataStack.push 0, ROUTER_STATIC_NODE, dept
					when ROUTER_PARAM_NODE # path param
						params= currentNode.params
						len= params.length
						while nodeIndex < len
							if params[nodeIndex].test part
								# save current index
								nodeStack.push currentNode
								metadataStack.push (nodeIndex+3), ROUTER_PARAM_NODE, dept
								# go to sub route
								currentNode= params[nodeIndex+2]
								++dept
								if dept < partsLen
									nodeStack.push currentNode
									metadataStack.push nodeIndex, ROUTER_STATIC_NODE, dept
								break
							nodeIndex+= 3
					when ROUTER_WILDCARD_PARAM_NODE # wildcard param
						params= currentNode.wildcards
						len= params.length
						pathEnd= parts.slice(dept).join('/')
						while nodeIndex < len
							if params[nodeIndex].test pathEnd
								# go to sub route
								currentNode= params[nodeIndex+2]
								dept= partsLen
								break
							nodeIndex+= 3
					when ROUTER_WILDCARD_NODE # wildcard
						currentNode= currentNode.wildcard
						dept= partsLen
					else
						throw "Unexpected error: Illegal nodeType #{nodeType}"
				# Check if found
				if (dept is partsLen) and (nodeH= currentNode.get)
					result.status= 200
					result.node= currentNode
					# Load wrappers and error handlers
					wrappers= result.wrappers
					# errHandlers= result.errorHandlers
					paramArr= result.params
					for node, j in currentNode.path
						# wrappers
						if arr= node.wrappers
							wrappers.push el for el in arr
						# # error handlers
						# if arr= node.onError
						# 	errHandlers.push el for el in arr
						# params
						switch node.type
							when ROUTER_PARAM_NODE, ROUTER_STATIC_PARAM_NODE
								paramArr.push node.param, parts[j]
							when ROUTER_WILDCARD_PARAM_NODE, ROUTER_WILDCARD_NODE
								paramArr.push node.param, parts.slice(j).join('/')
					break
		catch err
			err= new Error "ROUTER>> #{err}" if typeof err is 'string'
			result.status= 500
			result.error= err
		return result
