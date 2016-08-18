-- auth: baoxue
-- time: 2014.04.27

local only		= require('only')
local redis_api 	= require('redis_pool_api')
local APP_CONFIG_LIST	= require('CONFIG_LIST')
local supex 		= require('supex')
local luakv_api 	= require('luakv_pool_api')



module('freq', package.seeall)


-->> public
OWN_JOIN = {
	cause = {
		trigger_type = "every_time,one_day,power_on,fixed_time",
	}
}
OWN_MUST = {
	cause = {
		trigger_type = "every_time",
		fix_num = 1,
		delay = 0
	},
}

--keyName:oncePowerOn            place:?       	des:开机记录      action:w
function freq_init( uid )
	luakv_api.cmd("owner", uid, 'del', uid .. ':oncePowerOn')
end

function freq_filter( app_name, uid )
	local cause = APP_CONFIG_LIST["OWN_LIST"][app_name]["ways"]["cause"]
	local class = cause["trigger_type"]
	local num = cause["fix_num"]
	local delay = cause["delay"]
	--> func list
	local check_list = {
		every_time = function( ... )
			return true
		end,
		once_life = function( ... )
			local keyct = string.format("%s:onceAllLife", uid)
			local ok,val = redis_api.cmd("private_hash", uid, "sismember", keyct, app_name)
			if not ok then return false end
			if not val then
				redis_api.cmd("private_hash", uid, "sadd", keyct, app_name)
				return true
			else
				return false
			end
		end,
		power_on = function( ... )
			local keyct = string.format("%s:oncePowerOn", uid)
			local ok,val = luakv_api.cmd("owner", uid, "sismember", keyct, app_name)
			if not ok then return false end
			if not val then
				luakv_api.cmd("owner", uid, "sadd", keyct, app_name)
				return true
			else
				return false
			end
		end,
		one_day = function( ... )
			local keyct = string.format("%s:%s:everyDay", uid, app_name)
			local ok,val = luakv_api.cmd("owner", uid, "get", keyct)
			if not ok then return false end
			if not val then
				local over = 86400 - ((os.time() + 28800)%(86400))
				luakv_api.cmd("owner", uid, "set", keyct, 1)
				luakv_api.cmd("owner", uid, "expire", keyct, over)
			else
				if tonumber(val) >= num then return false end
				--[[
				if delay > 0 then
				local keydy = string.format("%s:%s:everyDelay", uid, app_name)
				local ok,val = luakv_api.cmd("private", uid, "get", keydy)
				if (not ok) or (not val) then return false end
				luakv_api.cmd("private", uid, "set", keydy, 1)
				luakv_api.cmd("private", uid, "expire", keydy, delay)
				end
				]]--
				luakv_api.cmd("owner", uid, "incr", keyct)
			end
			return true
		end,
		fixed_time = function( ... )
			local keyct = string.format("%s:%s:fixedInterval", uid, app_name)
			local ok,val = luakv_api.cmd("owner", uid, "get", keyct)
			if not ok then return false end
			if not val then
				luakv_api.cmd("owner", uid, "set", keyct, 1)
				luakv_api.cmd("owner", uid, "expire", keyct, delay)
			else
				if tonumber(val) >= num then return false end
				luakv_api.cmd("owner", uid, "incr", keyct)
			end
			return true
		end,
	}
	return check_list[ class ]( )
end

function freq_regain( app_name, uid )
	local cause = APP_CONFIG_LIST["OWN_LIST"][app_name]["ways"]["cause"]
	local class = cause["trigger_type"]
	local num = cause["fix_num"]
	local delay = cause["delay"]
	--> func list
	local regain_list = {
		every_time = function( ... )
			return true
		end,
		once_life = function( ... )
			local keyct = string.format("%s:onceAllLife", uid)
			local ok,val = redis_api.cmd("private_hash", uid, "srem", keyct, app_name)
			if not ok then return false end
			return true
		end,
		power_on = function( ... )
			local keyct = string.format("%s:oncePowerOn", uid)
			local ok,val = luakv_api.cmd("owner", uid, "srem", keyct, app_name)
			if not ok then return false end
			return true
		end,
		one_day = function( ... )
			local keyct = string.format("%s:%s:everyDay", uid, app_name)
			local ok,val = luakv_api.cmd("owner", uid, "get", keyct)
			if not ok then return false end
			if val and (tonumber(val) > 0) then
				luakv_api.cmd("owner", uid, "decr", keyct)
			end
			--[[
			if delay > 0 then
			local keydy = string.format("%s:%s:everyDelay", uid, app_name)
			luakv_api.cmd("private", uid, "del", keydy)
			end
			]]--
			return true
		end,
		fixed_time = function( ... )
			local keyct = string.format("%s:%s:fixedInterval", uid, app_name)
			local ok,val = luakv_api.cmd("owner", uid, "get", keyct)
			if not ok then return false end
			if val and (tonumber(val) > 0) then
				luakv_api.cmd("owner", uid, "decr", keyct)
			end
			return true
		end,
	}
	return regain_list[ class ]( )
end
