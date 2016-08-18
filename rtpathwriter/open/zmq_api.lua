local zmq = require('zmq')
local only = require('only')
local link = require('link')
local APP_LINK_ZMQ_LIST = link["OWN_POOL"]["zmq"]


module('zmq_api', package.seeall)

local OWN_ZMQ_POOLS = {}
local g_ctx = nil

function init( )
	g_ctx = zmq.init(1)
	local mold_list = {
		REQ = zmq.REQ,
		REP = zmq.REP,
		PUSH = zmq.PUSH,
		PULL = zmq.PULL,
		PUB = zmq.PUB,
	}
	for name in pairs( APP_LINK_ZMQ_LIST ) do
		local new_cfg = APP_LINK_ZMQ_LIST[name]
		local new_skt = g_ctx:socket( mold_list[ new_cfg["mold"] ] )
		new_skt:connect( string.format("tcp://%s:%d", new_cfg["host"], new_cfg["port"]) )
		print("|-------" .. name .. " zmq pool init------->" .. (new_skt and " OK!" or " FAIL!"))
		OWN_ZMQ_POOLS[ name ] = new_skt
	end
end


local function fetch_pool(zmqname)
	if not APP_LINK_ZMQ_LIST[zmqname] then
		only.log("E", "NO zmq named <--> " .. zmqname)
		return false
	end
	if not OWN_ZMQ_POOLS[zmqname] then
		return false
	end
	return true
end




function cmd(zmqname, cmds, ...)
	-->> zmqname, cmds, keyvalue1, keyvalue2, ...
	
	if not fetch_pool(zmqname) then
		return false,nil
	end
	
	return pcall(OWN_ZMQ_POOLS[zmqname][cmds], OWN_ZMQ_POOLS[zmqname], ...)
end
