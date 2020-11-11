# CONST
DEFAULT_OPTIONS=
	caseSensitive:			no
	ignoreTrailingSlash:	yes
	maxLoops:				1000
	cacheMax:				50
	run:					yes	# Run router when page loaded
	out: (url, isForced)->	# called when leaving the page
		document.location.replace url
		return
	catch: (err, ctx)->		# Catch goto errors. Example: {code: 404}
		CORE.fatalError 'ROUTER', err
		return
ROUTER_ROOT_PATH=	-1	# Is document root path (Document real path)
HISTORY_NO_STATE=	0	# do not insert state in history, use when calling history.back()
HISTORY_REPLACE=	1	# do replace in history instead of adding
HISTORY_BACK=		2	# prevent history push when back
ROUTER_RELOAD=		3	# Reload path
# Node types
ROUTER_STATIC_NODE= 0
ROUTER_PARAM_NODE= 1
ROUTER_WILDCARD_PARAM_NODE= 2
ROUTER_WILDCARD_NODE= 3
ROUTER_STATIC_PARAM_NODE= 4
# ROUTES
ROUTE_ILLEGAL_PATH_REGEX= /[#]|[^\/]\?/

PARAM_DEFAULT_REGEX= test: -> true
PARAM_DEFAULT_CONVERTER= (data)-> data
