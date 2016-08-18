local socket = require('socket')
local redis = require('redis')
local only = require('only')
local scan = require('scan')
local conhash = require('conhash')
local link = require('link')
local cutils = require('cutils')
local Queue = require("queue")
local cutils = require('cutils')

local APP_LINK_REDIS_LIST = link["OWN_POOL"]["redis"] or {}


module('redis_pool_api', package.seeall)


function reg( fcb, arg )
	redis.reg_idle_cb(fcb, arg)
end

local MAX_RECNT = 2
local MAX_SAME_SOCK = 64
local OWN_REDIS_POOLS = {}
local OWN_SKTCT_POOLS = {}

local function new_connect(host, port)
	local nb = 0
	local ok = nil
	local sock = nil
	---- dns from host to ip
	local host, err = cutils.domain2ipaddress(host)
	if not host then
		only.log('E', "cutils.domain2ipaddress failed, %s ", err)
		return false, nil
	end
	repeat
		nb = nb + 1
		ok, sock = pcall(redis.connect, socket, host, port)
		if not ok then
			only.log("E", sock)
			only.log("I", string.format('REDIS: %s:%d | RECNT: %d |---> Tcp:connect: FAILED!', host, port, nb))
			sock = nil
			if nb >= 1 then
				return false, nil
			end
		end
	until sock
	only.log("I", string.format('REDIS: %s:%d | RECNT: %d |---> Tcp:connect: SUCCESS!', host, port, nb))
	return true, sock
end

local function just_fetch_pool(redname, justkey)
	local list = OWN_REDIS_POOLS[ redname ]
	if not list then
		only.log("E", "NO redis named <--> " .. redname)
		return nil
	end
	local memb = list:hash(justkey)
	if not memb then
		only.log("E", "%s redis NO mark named <--> %s", redname, justkey)
		return nil
	end
	return memb
end

local function hash_fetch_pool(redname, hashkey)
	if not hashkey then
		only.log("E", "hashkey is not ok!")
		return nil
	end

	local list = OWN_REDIS_POOLS[ redname ]

	if not list then
		only.log("E", "NO redis named <--> " .. redname)
		return nil
	end

	local els = #list

	if els == 0 then
		only.log("E", "Empty redis named <--> " .. redname)
		return nil
	end

	local memb = nil
	if els > 1 then
		memb = list:hash(hashkey)
	else
		memb = list[1]
	end

	only.log("D", "REDNAME %s HASHKEY %s CONHASH TO %s:%d", redname, hashkey, memb["host"], memb["port"]);

	return memb
end



local function only_fetch_pool(redname)
	local list = OWN_REDIS_POOLS[ redname ]
	if not list then
		only.log("E", "NO redis named <--> " .. redname)
		return nil
	end
	if #list == 0 then
		only.log("E", "Empty redis named <--> " .. redname)
		return nil
	end
	local i = 1
	local memb = list[i]
	return memb
end



local function redis_cmd_use_pool(memb, cmds, ...)
	----------------------------
	-- start
	----------------------------
	cmds = string.lower(cmds)
	local skt_addr = memb["host"] .. ":" .. memb["port"]
	local queue = OWN_SKTCT_POOLS[ skt_addr ]
	----------------------------
	-- API
	----------------------------
	local stat,ret
	local index = 0
	repeat
		local sock = queue:pull()
		if not sock then
			ok, sock = new_connect( memb["host"], memb["port"] )
		end
		if sock then
			stat,ret = pcall(sock[ cmds ], sock, ...)
			if stat then
				queue:push(sock)
				--sock.network.socket:setkeepalive(0, 30)--> push socket to C pool. it will auto close when no set.
			else
				local l = string.format("%s |--->FAILED! %s . . .", cmds, ret)
				only.log("E", l)

				sock.network.socket:close()
				sock = nil
			end
		end
		index = index + 1
		if not stat and index >= MAX_RECNT then
			local l = string.format("do %s rounds |--->FAILED! this request failed!", MAX_RECNT)
			l = string.format("%s\n%s %s", l, cmds, scan.dump({...}))
			only.log("E", l)
			assert(false, l)
		end
	until stat
	----------------------------
	-- end
	----------------------------
	return ret
end

local function redis_cmd_out_pool(memb, cmds, ...)
	----------------------------
	-- start
	----------------------------
	cmds = string.lower(cmds)
	----------------------------
	-- API
	----------------------------
	local stat,ret
	local index = 0
	repeat
		local ok, sock = new_connect( memb["host"], memb["port"] )
		if sock then
			stat,ret = pcall(sock[ cmds ], sock, ...)
			if not stat then
				local l = string.format("%s |--->FAILED! %s . . .", cmds, ret)
				only.log("E", l)
			end
			sock.network.socket:close()
			sock = nil
		end
		index = index + 1
		if not stat and index >= MAX_RECNT then
			local l = string.format("do %s rounds |--->FAILED! this request failed!", MAX_RECNT)
			l = string.format("%s\n%s %s", l, cmds, scan.dump({...}))
			only.log("E", l)
			assert(false, l)
		end
	until stat
	----------------------------
	-- end
	----------------------------
	return ret
end

local redis_cmd = redis_cmd_use_pool

function init( )
	for name in pairs( APP_LINK_REDIS_LIST ) do
		local save = {}
		OWN_REDIS_POOLS[ name ] = save
		local list = APP_LINK_REDIS_LIST[name]
		if #list == 0 then
			local memb = {
				mode = "M",
				mark = "",
				host = list["host"],
				port = list["port"],
				vnode = 0,
			}

			local skt_addr = memb["host"] .. ":" .. memb["port"]
			local queue = OWN_SKTCT_POOLS[ skt_addr ]
			if not queue then
				queue = Queue:new( MAX_SAME_SOCK )
				OWN_SKTCT_POOLS[ skt_addr ] = queue
			end

			local ok, sock = new_connect( memb["host"], memb["port"] )
			if ok then
				queue:push(sock)
				local sock = queue:pull()
				sock.network.socket:close()
				sock = nil
			end
			print( string.format("|-------%s redis pool 1/1 init-------> %s", name, (ok and "OK!" or "FAIL!")) )
			save[1] = memb
		elseif list["hash"] == 'customer' then
			--hash函数定位元素位置
			save["hash"] = function ( self, hashkey )
				local i = 0;
				local els = #self;

				if els > 0 and hashkey then
					i = cutils.custom_hash(hashkey, els, 0) + 1;
					if i > els or i < 1 then
						i = 1;
					end
					return self[i];
				end

				return nil;
			end

			for i, info in ipairs(list) do
				local memb = {
					mode = info[1],
					mark = info[2],
					host = info[3],
					port = info[4],
					vnode = info[5],
				}

				local skt_addr = memb["host"] .. ":" .. memb["port"]
				local queue = OWN_SKTCT_POOLS[ skt_addr ]
				if not queue then
					queue = Queue:new( MAX_SAME_SOCK )
					OWN_SKTCT_POOLS[ skt_addr ] = queue
				end

				local ok, sock = new_connect( memb["host"], memb["port"] )
				if ok then
					queue:push(sock)
					local sock = queue:pull()
					sock.network.socket:close()
					sock = nil
				end
				print( string.format("|-------%s redis pool %d/%d init-------> %s", name, i, #list, (ok and "OK!" or "FAIL!")) )
				save[i] = memb;
			end
		elseif list["hash"] == 'consistent' then
			local root = conhash.init()
			save["root"] = root
			save["hash"] = function ( self, hashkey )
				local node = conhash.lookup(self["root"], hashkey)
				if not node then
					return nil
				end
				return self[self[node]];
			end
			--[[
			save = {
			"root" = root,

			memb,
			"host:port" = 0,

			memb`,
			"host`,port`" = 1,
			}
			]]
			for i, info in ipairs(list) do
				local memb = {
					mode = info[1],
					mark = info[2],
					host = info[3],
					port = info[4],
					vnode = info[5],
				}

				local skt_addr = memb["host"] .. ":" .. memb["port"]
				local queue = OWN_SKTCT_POOLS[ skt_addr ]
				if not queue then
					queue = Queue:new( MAX_SAME_SOCK )
					OWN_SKTCT_POOLS[ skt_addr ] = queue
				end

				local ok, sock = new_connect( memb["host"], memb["port"] )
				if ok then
					queue:push(sock)
					local sock = queue:pull()
					sock.network.socket:close()
					sock = nil
				end
				print( string.format("|-------%s redis pool %d/%d init-------> %s", name, i, #list, (ok and "OK!" or "FAIL!")) )
				save[i] = memb

				local node = string.format("%s:%d", memb["host"], memb["port"])
				conhash.set(root, node, memb["vnode"])
				save[node] = i
			end
		elseif list["hash"] == 'appoint' then
			save["hash"] = function ( self, hashkey )
				return self[hashkey];
			end

			for i, info in ipairs(list) do
				local memb = {
					mode = info[1],
					mark = info[2],
					host = info[3],
					port = info[4],
					vnode = info[5],
				}
				local just = info[2]
				if save[ just ] then
					assert(false, string.format("[ERROR] (%s) redis pool mark (%s) have already exist!", name, just))
				end

				local skt_addr = memb["host"] .. ":" .. memb["port"]
				local queue = OWN_SKTCT_POOLS[ skt_addr ]
				if not queue then
					queue = Queue:new( MAX_SAME_SOCK )
					OWN_SKTCT_POOLS[ skt_addr ] = queue
				end

				local ok, sock = new_connect( memb["host"], memb["port"] )
				if ok then
					queue:push(sock)
					local sock = queue:pull()
					sock.network.socket:close()
					sock = nil
				end
				print( string.format("|-------%s redis pool %d/%d init-------> %s", name, i, #list, (ok and "OK!" or "FAIL!")) )
				save[ just ] = memb;
			end
		else
			assert(false, "[ERROR] Wrong hash strategy!")
		end
	end
	only.log("S", '[OWN_REDIS_POOLS:%s]', scan.dump(OWN_REDIS_POOLS))
end

function entry_cmd(memb, ...)
	local ok, result
	if type(...) == 'table' then
		local results = setmetatable({}, { __mode = 'kv' })
		for i, subtab in ipairs(...) do
			if type(subtab) ~= 'table' then
				only.log("E", "error args to call redis_api.cmd(...)")
				break
			end
			ok, result = pcall(redis_cmd, memb, unpack(subtab))
			if not ok then
				only.log("E", string.format("call redis_api.cmd(...) fail by %s: %s",
				scan.dump(...), result))
				return ok, result
			end

			results[i] = result
		end

		return ok, results
	else
		ok, result = pcall(redis_cmd, memb, ...)
		if not ok then
			only.log("E", string.format("call redis_api.cmd(...) fail by %s: %s",
			scan.dump(...), result))
		end
		return ok, result
	end
end

-->|	local args = {...}
-->|	local cmd, kv1, kv2 = unpack(args)
function just_cmd(redname, justkey, ...)
	-->> redname, justkey, cmd, keyvalue1, keyvalue2, ...
	-->> redname, justkey, {{cmd, keyvalue1, keyvalue2, ...}, {...}, ...}

	local memb = just_fetch_pool(redname, justkey)
	if not memb then
		return false,nil,nil
	end

	local ok, result = entry_cmd(memb, ...)
	return ok, result, memb
end

-->|	local args = {...}
-->|	local cmd, kv1, kv2 = unpack(args)
function hash_cmd(redname, hashkey, ...)
	-->> redname, hashkey, cmd, keyvalue1, keyvalue2, ...
	-->> redname, hashkey, {{cmd, keyvalue1, keyvalue2, ...}, {...}, ...}

	local memb = hash_fetch_pool(redname, hashkey)
	if not memb then
		return false,nil,nil
	end

	local ok, result = entry_cmd(memb, ...)
	return ok, result, memb
end

-->|	local args = {...}
-->|	local cmd, kv1, kv2 = unpack(args)
function only_cmd(redname, ...)
	-->> redname, cmd, keyvalue1, keyvalue2, ...
	-->> redname, {{cmd, keyvalue1, keyvalue2, ...}, {...}, ...}

	local memb = only_fetch_pool(redname)
	if not memb then
		return false,nil,nil
	end

	local ok, result = entry_cmd(memb, ...)
	return ok, result, memb
end

cmd = hash_cmd

-->| Original redis_pool_api can not add redis connection after initialization of redis_pool_api.
-->| When a tsdb znode add to the znode tree of zookeeper after initialization of redis_pool_api, 
-->| zoo_wget_children watcher callback will call this function to add a new tsdb connection
-->| to the redis connection pool.
function add_to_pool(redname, host, port)
	if not APP_LINK_REDIS_LIST[redname] then
		APP_LINK_REDIS_LIST[redname] = {
			host = host,
			port = port
		}
	end

	if OWN_REDIS_POOLS[ redname ] then
		return
	end

	local save = {}
	OWN_REDIS_POOLS[ redname ] = save
	local list = APP_LINK_REDIS_LIST[redname]
	if #list == 0 then
		local memb = {
			mode = "M",
			mark = "",
			host = list["host"],
			port = list["port"],
			vnode = 0,
		}
		table.insert(save, memb)
	end
end

-->| Original redis_pool_api can not delete redis connection after initialization of redis_pool_api.
-->| When a tsdb znode was deleted from the znode tree of zookeeper after initialization of redis_pool_api, 
-->| the callback of zoo_wget_children watcher will call this function to delete the tsdb connection
-->| from the redis connection pool.
function del_from_pool(redname)
	if not OWN_REDIS_POOLS[ redname ] then
		return
	end

	local list = OWN_REDIS_POOLS[ redname ]
	if list and #list > 0 then
		local memb = list[1]
		memb = nil
	end
	OWN_REDIS_POOLS[ redname ] = nil

	if APP_LINK_REDIS_LIST[redname] then
		APP_LINK_REDIS_LIST[redname] = nil
	end
end

