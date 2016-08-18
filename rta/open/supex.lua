local scan 		= require('scan')
local utils 		= require('utils')
local cutils 		= require('cutils')
local supex_http	= _G.supex_http
local supex_say		= _G.app_lua_add_send_data
local supex_diffuse	= _G.app_lua_diffuse

module("supex", package.seeall)

__WORK_TYPE__	= false
__SERV_NAME__	= app_lua_get_serv_name()
__TASKER_SCHEME__	= 0
__TASKER_NUMBER__	= 0

_FINAL_STAGE_	= false
_SOCKET_HANDLE_	= 0
--
-- http function
--
function http(host, port, data, size)
	return supex_http(__TASKER_SCHEME__, host, port, data, size)
end

function diffuse(name, data, time, mode)
	return supex_diffuse(name, data, time, mode)
end

function spill(data)
	return supex_say(_SOCKET_HANDLE_, data)
end

function rgs( status )
	local afp = { }
	setmetatable(afp, { __index = _M })
	afp.status = status

	afp.fsize = 0
	afp.fdata = { }

	return afp
end

function say(afp, data)
	table.insert(afp.fdata, data)
	afp.fsize = afp.fsize + data:len()
end

function over(afp, ftype)
	--> update body
	local body = table.concat(afp.fdata)
	--> update head
	local head = ''
	if ftype then
		head = string.format('HTTP/1.1 %s OK\r\nServer: supex/1.0.0\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n', afp.status, ftype , afp.fsize)
	else
		head = string.format('HTTP/1.1 %s OK\r\nServer: supex/1.0.0\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n', afp.status, afp.fsize)
	end
	--> flush data
	local data = head .. body
	return supex_say(_SOCKET_HANDLE_, data)
end

--------------------------------------------------------------
local http_req_method		= nil
local http_req_path		= nil
local http_req_uri		= nil
local http_req_info		= nil
local http_req_head		= nil
local http_req_body		= nil
local http_req_uri_table	= {}
local http_req_body_table	= {}

function http_req_init( )
	http_req_method		= nil
	http_req_path		= nil
	http_req_uri		= nil
	http_req_info		= nil
	http_req_head		= nil
	http_req_body		= nil
	http_req_uri_table	= {}
	http_req_body_table	= {}
end
--------------------------------------------------------------
function set_our_method( method )
	http_req_method = method
end

function set_our_path( path )
	http_req_path = string.gsub(path or "", "^([^/])", "/%1", 1)
end

function set_our_uri_args( args )
	http_req_uri = cutils.url_decode( args or "" )
end

function set_our_info_data( msg )
	http_req_info = msg
end

function set_our_head( head )
	http_req_head = head
end

function set_our_body_data( body )
	http_req_body = body
end

function set_our_uri_table( )
	http_req_uri_table = utils.parse_url( http_req_uri ) or {}
end

function set_our_body_table( )
	http_req_body_table = utils.parse_http_body_data(http_req_head, http_req_body) or {}
end
--------------------------------------------------------------
function get_our_method( ... )
	return http_req_method
end

function get_our_path( ... )
	return http_req_path
end

function get_our_uri_args( ... )
	return http_req_uri
end

function get_our_info_data( ... )
	return http_req_info
end

function get_our_head( ... )
	return http_req_head
end

function get_our_body_data( ... )
	return http_req_body
end

function get_our_uri_table( ... )
	return http_req_uri_table or {}
end

function get_our_body_table( ... )
	return http_req_body_table or {}
end
