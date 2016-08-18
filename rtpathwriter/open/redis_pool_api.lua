local socket = require('socket')
local redis = require('redis')
local only = require('only')
local scan = require('scan')
local conhash = require('conhash')
local link = require('link')
local cutils = require('cutils')

local APP_LINK_REDIS_LIST = link["OWN_POOL"]["redis"]


module('redis_pool_api', package.seeall)


function reg( fcb, arg )
	redis.reg_idle_cb(fcb, arg)
end

local MAX_RECNT = 3
local MAX_DELAY = 20
local OWN_REDIS_POOLS = {}

local function new_connect(memb)
	local nb = 0
	local ok = nil
	memb["rcnt"] = (memb["rcnt"] or 0)
	repeat
		nb = nb + 1
		ok,memb["sock"] = pcall(redis.connect, memb["host"], memb["port"])
		if not ok then
			memb["rcnt"] = memb["rcnt"] + 1
			socket.select(nil, nil, 0.05 * ((memb["rcnt"] >= MAX_DELAY) and MAX_DELAY or memb["rcnt"]))
			only.log("E", memb["sock"])
			only.log("I", string.format('REDIS: %s:%d | RECNT: %d |---> Tcp:connect: FAILED!', memb["host"], memb["port"], memb["rcnt"]))
			memb["sock"] = nil
		end
		if nb >= MAX_RECNT then
			return false
		end
	until memb["sock"]
	only.log("I", string.format('REDIS: %s:%d | RECNT: %d |---> Tcp:connect: SUCCESS!', memb["host"], memb["port"], memb["rcnt"]))
	memb["rcnt"] = 0
	return true
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
	if not memb["sock"] then
		if not new_connect( memb ) then
			return nil
		end
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

	--only.log("D", "REDNAME %s HASHKEY %s CONHASH TO %s:%d", redname, hashkey, memb["host"], memb["port"]);

	if memb and not memb["sock"] then
		if not new_connect( memb ) then
			return nil
		end
	end

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
	if not memb["sock"] then
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


local function redis_cmd(memb, cmds, ...)
	----------------------------
	-- start
	----------------------------
	cmds = string.lower(cmds)
	----------------------------
	-- API
	----------------------------
	local stat,ret
	local cnt = true
	local index = 0
	repeat
		if cnt then
			stat,ret = pcall(memb["sock"][ cmds ], memb["sock"], ...)
		end
		if not stat then
			local l = string.format("%s |--->FAILED! %s . . .", cmds, ret)
			only.log("E", l)
			cnt = flush_pool(memb)
		end
		index = index + 1
		if index >= MAX_RECNT then
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
				sock = nil,
				rcnt = 0
			}
			local ok = new_connect( memb )
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
					sock = nil,
					rcnt = 0
				}
				local ok = new_connect( memb )
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
					sock = nil,
					rcnt = 0
				}
				local ok = new_connect( memb )
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
					sock = nil,
					rcnt = 0
				}
				local just = info[2]
				if save[ just ] then
					assert(false, string.format("[ERROR] (%s) redis pool mark (%s) have already exist!", name, just))
				end
				local ok = new_connect( memb )
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
			sock = nil,
			rcnt = 0
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
		if memb["sock"] then
			memb["sock"].network.socket:close()
			memb["sock"] = nil
		end
		memb = nil
	end
	OWN_REDIS_POOLS[ redname ] = nil

	if APP_LINK_REDIS_LIST[redname] then
		APP_LINK_REDIS_LIST[redname] = nil
	end
end

