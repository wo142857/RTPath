local socket = require('socket')
local only = require('only')
local scan = require('scan')
local link = require('link')

local APP_LINK_TCP_LIST = link["OWN_POOL"]["tcp"]

module('tcp_pool_api', package.seeall)

local MAX_RECNT = 3
local MAX_DELAY = 20
local OWN_TCP_POOLS = {}
local tcp = nil
local function new_connect(memb)
	local nb = 0
	local ok = nil
	repeat
		tcp = socket.tcp()
		if not tcp then
			break
		end
		nb = nb + 1
		memb["sock"] = tcp:connect(memb["host"], memb["port"])
		if not memb["sock"] then
			memb["rcnt"] = memb["rcnt"] + 1
			socket.select(nil, nil, 0.05 * ((memb["rcnt"] >= MAX_DELAY) and MAX_DELAY or memb["rcnt"]))
			only.log("I", string.format('REDIS: %s:%d | RECNT: %d |---> Tcp:connect: FAILED!', memb["host"], memb["port"], memb["rcnt"]))
			memb["sock"] = nil
		end
		if nb >= MAX_RECNT then
			return false
		end
	until memb["sock"] or tcp
	only.log("I", string.format('REDIS: %s:%d | RECNT: %d |---> Tcp:connect: SUCCESS!', memb["host"], memb["port"], memb["rcnt"]))
	memb["rcnt"] = 0
	return true
end

local function tcp_pool(redname, data)
	if not data then
		only.log("E", "data is nil")
		return nil
	end

	local list = OWN_TCP_POOLS[ redname ]

	if not list then
		only.log("E", "NO tcp named <--> " .. redname)
		return nil
	end

	local els = #list

	if els == 0 then
		only.log("E", "Empty tcp named <--> " .. redname)
		return nil
	end

	memb = list[1]

	if memb and not memb["sock"] then
		if not new_connect( memb ) then
			return nil
		end
	end

	return memb
end

local function flush_pool(memb)
	if memb["sock"] then
		memb["sock"].network.socket:close()
		memb["sock"] = nil
	end
	return new_connect(memb)
end

function init( )
	for name in pairs( APP_LINK_TCP_LIST ) do
		local save = {}
		OWN_TCP_POOLS[ name ] = save
		local list = APP_LINK_TCP_LIST[name]
		if #list == 0 then
			local memb = {
				host = list["host"],
				port = list["port"],
				rcnt = 0
			}
			local ok = new_connect( memb )
			print( string.format("|-------%s TCP 1/1 init-------> %s", name, (ok and "OK!" or "FAIL!")) )
			save[1] = memb
		else

			for i, info in ipairs(list) do
			local memb = {
                                        host = info[1],
                                        port = info[2],
					rcnt = 0
                                }
                                local ok = new_connect( memb )
                                print( string.format("|-------%s TCP %d/%d init-------> %s", name, i, #list, (ok and "OK!" or "FAIL!")) )
                                save[i] = memb;
                        end
		end
	end
end

function entry_cmd(data)
	tcp:send(data)
	local result = tcp:receive("*a")
	if result then
		only.log('D',result)
	end
	return true
end

function cmd(redname, data, ...)

	local memb = tcp_pool(redname, data)
	if not memb then
		return false,nil,nil
	end

	local ok = entry_cmd(data)
	return ok, memb
end

function add_to_pool(redname, host, port)
	if not APP_LINK_TCP_LIST[redname] then
		APP_LINK_TCP_LIST[redname] = {
			host = host,
			port = port
		}
	end

	local save = {}
	OWN_TCP_POOLS[ redname ] = save
	local list = APP_LINK_TCP_LIST[redname]
	if #list == 0 then
		local memb = {
			host = list["host"],
			port = list["port"],
			rcnt = 0
		}
		table.insert(save, memb)
	end
end

function del_from_pool(redname)
	local list = OWN_TCP_POOLS[ redname ]
	if list and #list > 0 then
		local memb = list[1]
		if memb["sock"] then
			memb["sock"].network.socket:close()
			memb["sock"] = nil
		end
		memb = nil
	end
	OWN_TCP_POOLS[ redname ] = nil

	if APP_LINK_TCP_LIST[redname] then
		APP_LINK_TCP_LIST[redname] = nil
	end
end

