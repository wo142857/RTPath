
module("scene", package.seeall)

_SCENE_LIST_	= {}

function init( )
	_SCENE_LIST_ = {}
end

function pack( )
	return _SCENE_LIST_
end

function push( name, info )
	_SCENE_LIST_[name] = info or {}
end

function view( name )
	return _SCENE_LIST_[name]
end
