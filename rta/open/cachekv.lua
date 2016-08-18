--[[
        cache_rediskv.lua
        
        通过配置每个键的缓存时间，达到在一定时间内缓存redis的数据到本地libkv中。

        Created by 周凯 on 15/7/8.
        Copyright (c) 2015年 zk. All rights reserved.
]]



local only              = require('only')
local redis_api         = require('redis_pool_api')
local luakv_api         = require('luakv_pool_api')
local scan              = require('scan')
local log               = require('lualog')
module('cachekv', package.seeall)


local CACHEKV = {
      -- [':IMEI'] = 5 * 60 ,
      -- [':configTimestamp'] = 5 * 60 ,
      -- [':userMsgSubscribed'] = 5 * 60 ,
      -- [':travelID'] = 5 * 60 ,
      -- [':cityCode'] = 5 * 60 ,
      -- [':homeCityCode'] = 1 * 60 * 60 * 24
}

local _suffixedstartchar = ':'
local _defaultexpiretime = 1

local function getexpiretime( server, hash, key, issuffixed )
        -- body
        local expiretime = nil
        if issuffixed then
                local _, _, suffixed = string.find(key, string.format('.*(%s[%%w%%_]*)$', _suffixedstartchar))
                expiretime = CACHEKV[suffixed]
        else
                expiretime = CACHEKV[key]
        end

        return tonumber(expiretime or _defaultexpiretime)
end

local function setexpiretime( server, hash, key, issuffixed )
        -- body
        local expiretime = getexpiretime(server, hash, key, issuffixed)
        if expiretime > 0 then
                --return luakv_api.cmd(server, hash, 'expire', key, expiretime)
        end
        return true, 1
end

--[[
支持单条命令形式
且暂时只支持get,smembers命令
1.查找libkv，没有找到则查询redis
2.查到value后，根据配置表设置超时
]]
local function getcachekv( issuffixed, server, hash, ... )
        -- body
        -- local cmd, key = ...
        local cmd, key, field = ...
        local ok, result = nil, nil
        if type(...) == 'table' or 
                (cmd ~= 'get' and cmd ~= 'smembers' and cmd ~= 'hget') then
                ok, result = false, "not supported this operation."
        else
                ok, result = luakv_api.cmd(server, hash, ...)
                if ok and (not result or #result == 0) then
                        local flag = nil
                        ok, result = redis_api.cmd(server, hash, ...)
                        if ok and result and #result > 0 then
                              
				local cmd_map_list = setmetatable( {
					["get"] = function( )
						return luakv_api.cmd(server, hash, 'set', key, result)
					end,
					["smembers"] = function( )
						return luakv_api.cmd(server, hash, 'sadd', key, table.concat( result, " " ))
					end,
                                        ["hget"] = function ( )
                                                return luakv_api.cmd(server, hash, 'hset', key, field, result)
                                        end,
				}, {
					__index = function ( _, cmd )
						return function ( )
                                                        return false, tostring(cmd) .. " not supported this operation."
                                                end
					end
				})

				ok, flag = cmd_map_list[ cmd ]( )

                                if ok then
                                        ok, flag = setexpiretime(server, hash, key, issuffixed)
                                end

                                if not ok then
                                        result = flag
                                end
                        end 
                end
        end

        

        if not ok then
                only.log('E', 'server : %s, command : %s, case : %s', 
                        server, scan.dump({...}), scan.dump(result));
        end

        return ok, result
end


--[[
执行设置类的命令
同时在redis/libkv中进行操作
当命令是set/sadd时进行过期值的刷新
]]
local function setcachekv( issuffixed, server, hash, ... )
        -- body
        local setexptm = function ( cmd, key )
                if cmd == 'set' or cmd == 'sadd' or 
                   cmd == 'hset' then--FIXME:need update
                        return setexpiretime(server, hash, key, issuffixed)
                end
        end

        local ok, result = redis_api.cmd(server, hash, ...)
        if ok then
                ok, result = luakv_api.cmd(server, hash, ...)
                if ok then
                        if type(...) == 'table' then
				for i,v in ipairs(...) do
					local cmd, key = unpack(v)
                                        ok, result = setexptm(cmd, key)
                                        if not ok then
                                                break;
                                        end
				end
                        else
                                local cmd, key = ...
                                ok, result = setexptm(cmd, key)
                        end
                end
        end

        if not ok then
                only.log('E', 'server : %s, command : %s, case : %s',
                        server, scan.dump({...}), scan.dump(result));
        end

        return ok, result
end

function init_expire_keys( list )
        -- body
        assert(type(list) == 'table')
        CACHEKV = {}
        for key, val in pairs( list ) do
        	CACHEKV[key] = tonumber(val)
        end
end

--[[
以键的后缀搜索KV过期配置表
]]
function pull( server, hash, ... )
        -- body
        return getcachekv(true, server, hash, ...)
end
--[[
以键的本身搜索KV过期配置表
]]
function pull_fk( server, hash, ... )
        -- body
        return getcachekv(false, server, hash, ...)
end





--[[
以键的后缀搜索KV过期配置表
]]
function push( server, hash, ... )
        -- body
        return setcachekv(true, server, hash, ...)
end
--[[
以键的本身搜索KV过期配置表
]]
function push_fk( server, hash, ... )
        -- body
        return setcachekv(false, server, hash, ...)
end


--<=============================================================================================>--
--[[
function lru_hash_cache_set(server, hash, key, value, value_len)
	only.log('D', string.format("[server:%s][hashkey:%s][key:%s][value:%s][value_len:%s]", server or '', hash or '', key or '', value or '', value_len or ''))
	redis_api.cmd(server, hash, 'set', key, value)
	local ok, ret = app_lua_lru_cache_set_value(key, value, value_len)
	if not ok then
		only.log('D', string.format("[set value cache error][ret :%s]\n", ret or ''))
	end
end
function lru_hash_cache_get(server, hash, key)
	local ok, value = app_lua_lru_cache_get_value(key) 
	only.log('D', string.format("[server:%s][hashkey:%s][get value][key:%s][ok:%s][value:%s]", server or '', hash or '',key or '', ok or '', value or ''))
	if not ok then
		ok,value= redis_api.cmd(server, hash, 'get', key)
		if ok and value then
			local ok, ret = app_lua_lru_cache_set_value(key, value, #value)
			if not ok then
				only.log('D', string.format("[set value :ret :%s]\n", ret or ''))
			end
		else
			only.log('I', string.format("get value of [key:%s] from redis error", key or ''))
			value = nil
		end
	end
	return true, value
end
]]--
