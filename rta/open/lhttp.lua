local lhttp = {
	_VERSION     = 'lhttp-lua 2.0.5-dev',
	_DESCRIPTION = 'A Lua client library for the lhttp key value storage system.',
	_COPYRIGHT   = 'Copyright (C) 2009-2012 Daniele Alessandri',
}
local lhp = require 'lua-http-message.http.parser'

--module('lhttp', package.seeall)

function shallowcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = orig_value
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end
-- ############################################################################
local network = {}

function network.write(client, buffer)
	local byte, err = client.network.socket:send(buffer)
	if err then client.error(err) end
	return byte
end

function network.read(client, len)
	if len == nil then len = '*l' end
	local res, err = client.network.socket:receive(len)
	local ok = res and true or false
	if ok then
		return ok, res
	else
		return ok, err
	end
end



-- ############################################################################

local defaults = {
	host        = '127.0.0.1',
	port        = 80,
	tcp_nodelay = true,
	path        = nil,
}

local idle_fcb,idle_arg = nil, nil

-- triggered in nonblock status
function lhttp.reg_idle_cb(fcb, arg)
	assert(type(fcb) == "nil" or type(fcb) == "function", "'fcb' should be function type!")
	local old_idle_fcb, old_idle_arg = idle_fcb, idle_arg

	idle_fcb = fcb
	idle_arg = arg
	return old_idle_fcb, old_idle_arg
end

local function custom_request(client, query)
	if type(query) == 'string' then
		repeat
			local out = client.network.write(client, query)
			print("send size:", out)
			query = string.sub(query, out + 1, -1)
		until (#query == 0)
	else
		client.error('argument error: ' .. type(query))
	end

	local idle_fcb = idle_fcb
	local idle_arg = idle_arg
	if idle_fcb then
		client.network.socket:settimeout(0) --noblock
	else
		client.network.socket:settimeout(nil) -- restore to block indefinitely
	end

	local reply = {
		is_finish = false,
		origin_time = os.time(),
		finish_time = nil,

		status_code = nil,
		should_keep_alive = nil,

		data = '',
		body = '',
	}

	local cbs = {}
	function cbs.on_body(chunk)
		if chunk then reply["body"] = reply["body"] .. chunk end
	end
	function cbs.on_message_complete()
		reply["is_finish"] = true
		reply["finish_time"] = os.time()
	end
	local parser = lhp.response(cbs)
	while true do
		local ok, append = client.network.read(client, 1024)
		--print("\x1B[1;35m".."~~~~".."\x1B[m", ok, append)
		if not ok then
			if append == "closed" then
				if #reply["data"] == 0 then
					client.error('connection error: closed')
				end
				cbs.on_message_complete()
			end
			if append == "timeout" then
				--EWOULDBLOCK
				if idle_fcb then
					idle_fcb(idle_arg)
				end
			end
			if append ~= "timeout" and append ~= "closed" then
				print("ERROR", append)
			end
		elseif append then
			parser:execute(append)
			reply["data"] = reply["data"] .. append
		end
		if reply["is_finish"] then
			reply["status_code"] = parser:status_code()
			reply["should_keep_alive"] = parser:should_keep_alive()
			return reply
		end
	end
end


local function merge_defaults(parameters)
	if parameters == nil then
		parameters = {}
	end
	for k, v in pairs(defaults) do
		if parameters[k] == nil then
			parameters[k] = defaults[k]
		end
	end
	return parameters
end

local function parse_boolean(v)
	if v == '1' or v == 'true' or v == 'TRUE' then
		return true
	elseif v == '0' or v == 'false' or v == 'FALSE' then
		return false
	else
		return nil
	end
end




local function load_methods(proto, commands)
	local client = setmetatable ({}, getmetatable(proto))

	for cmd, fn in pairs(commands) do
		if type(fn) ~= 'function' then
			lhttp.error('invalid type for command ' .. cmd .. '(must be a function)')
		end
		client[cmd] = fn
	end

	for i, v in pairs(proto) do
		client[i] = v
	end

	return client
end

local function create_client(proto, client_socket, commands)
	local client = load_methods(proto, commands)
	client.error = lhttp.error
	client.network = {
		socket = client_socket,
		read   = network.read,
		write  = network.write,
	}
	return client
end

local client_prototype = {}

local function connect_tcp(socket, parameters)
	local host, port = parameters.host, tonumber(parameters.port)
	if parameters.timeout then
		socket:settimeout(parameters.timeout, 't')
	end

	local ok, err = socket:connect(host, port)
	if not ok then
		lhttp.error('could not connect to '..host..':'..port..' ['..err..']')
	end
	socket:setoption('tcp-nodelay', parameters.tcp_nodelay)
	return socket
end

local function connect_unix(socket, parameters)
	local ok, err = socket:connect(parameters.path)
	if not ok then
		lhttp.error('could not connect to '..parameters.path..' ['..err..']')
	end
	return socket
end

local function create_connection(skt_class, parameters)
	if parameters.socket then
		return parameters.socket
	end

	local perform_connection, socket

	if parameters.scheme == 'unix' then
		perform_connection, socket = connect_unix, skt_class.unix
		--perform_connection, socket = connect_unix, require('socket.unix')
		assert(socket, 'your build of LuaSocket does not support UNIX domain sockets')
	else
		if parameters.scheme then
			local scheme = parameters.scheme
			assert(scheme == 'lhttp' or scheme == 'tcp', 'invalid scheme: '..scheme)
		end
		perform_connection, socket = connect_tcp, skt_class.tcp
	end

	return perform_connection(socket(), parameters)
end

-- ############################################################################

function lhttp.error(message, level)
	error(message, (level or 1) + 1)
	print("===================")
end

function lhttp.connect(skt_class, ...)
	local args, parameters = {...}, nil

	local skt_class = shallowcopy(skt_class)
	if #args == 1 then
		if type(args[1]) == 'table' then
			parameters = args[1]
		else
			local uri = skt_class.url
			--local uri = require('socket.url')
			parameters = uri.parse(select(1, ...))
			if parameters.scheme then
				if parameters.query then
					for k, v in parameters.query:gmatch('([-_%w]+)=([-_%w]+)') do
						if k == 'tcp_nodelay' or k == 'tcp-nodelay' then
							parameters.tcp_nodelay = parse_boolean(v)
						elseif k == 'timeout' then
							parameters.timeout = tonumber(v)
						end
					end
				end
			else
				parameters.host = parameters.path
			end
		end
	elseif #args > 1 then
		local host, port, timeout = unpack(args)
		parameters = { host = host, port = port, timeout = tonumber(timeout) }
	end

	local commands = lhttp.commands or {}
	if type(commands) ~= 'table' then
		lhttp.error('invalid type for the commands table')
	end

	local socket = create_connection(skt_class, merge_defaults(parameters))
	local client = create_client(client_prototype, socket, commands)

	return client
end




lhttp.commands = {
	origin           = custom_request,
}
return lhttp
