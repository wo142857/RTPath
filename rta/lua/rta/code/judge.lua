-- auth: baoxue
-- time: 2014.04.27

local redis_api 	= require('redis_pool_api')
local supex 		= require('supex')
local scene 		= require('scene')
local only		    = require('only')
local cachekv 		= require('cachekv')
local FUNC_LIST	    = require('CONFIG_LIST')
local luakv_api     = require('luakv_pool_api')

module('judge', package.seeall)




--keyName:onceStepKeysSet   	place:owner  		des:记录种类递增key的集合  action:r
function reach_another_step_init(accountID)
	local ok, keys = luakv_api.cmd("owner", accountID, "smembers", accountID .. ":onceStepKeysSet")
	if ok then
		for i, v in ipairs(keys) do
			luakv_api.cmd("owner", accountID, "del", keys[i])
		end
		luakv_api.cmd("owner", accountID, "del", accountID .. ":onceStepKeysSet")
	end
end

local function reach_another_step(app_name, accountID, idx_key, index)
	local keyct1 = string.format("%s:onceStepKeysSet", accountID)
	local keyct2 = string.format("%s:%s:onceStepSet", accountID, app_name)
	local accountID = supex.get_our_body_table()["accountID"]

	luakv_api.cmd("owner", accountID, "sadd", keyct1, keyct2)
	local ok,val = luakv_api.cmd("owner", accountID, "sismember", keyct2, index)
	if not ok then return false end
	if not val then
		--[[
		if idx_key then
		local keyct0 = string.format("%s:%s", accountID, idx_key)
		redis_api.cmd("owner", accountID, "set", keyct0, index)
		end
		]]--
		luakv_api.cmd("owner", accountID, "sadd", keyct2, index)
		return true
	else
		return false
	end
end



--名 称:is_continuous_driving_mileage_point
--功 能:连续驾驶的业务逻辑
--参 数:app_name 应用名字
--返回值:符合要求返回true,不符合返回false
--修 改:修改业务    jizhong　2015/07/22
--逻辑：十公里的倍数必定下发(10\20\30\.....)，5公里的倍数时并且下发间隔时间大于两分钟再次下发(5\15\25 .....)

function is_continuous_driving_mileage_point(app_name)
	local accountID     = supex.get_our_body_table()["accountID"]
	local IMEI          = supex.get_our_body_table()["IMEI"]
	local actualMileage = supex.get_our_body_table()["T_LONGDRI_MILEAGE"]["actualMileage"]
	local maxSpeed      = supex.get_our_body_table()["T_LONGDRI_MILEAGE"]["maxSpeed"]
	local avgSpeed      = supex.get_our_body_table()["T_LONGDRI_MILEAGE"]["avgSpeed"]
	local stopTime      = supex.get_our_body_table()["T_LONGDRI_MILEAGE"]["stopTime"]
	local increase      = FUNC_LIST["OWN_LIST"][app_name]["bool"]["is_continuous_driving_mileage_point"]["increase"]
	increase  =  increase and tonumber(increase) or 10

	only.log('D', string.format("rtmiles judge, IMEI:%s, actualMileage:%s",IMEI, actualMileage))
	if actualMileage == 0 then
		luakv_api.cmd('driview', accountID, 'set', accountID .. "controlFrequency", os.time())
		return false
	end
	if  (not actualMileage) and (not maxSpeed) and (not avgSpeed) and (not stopTime)then
		return false
	end


	local actual_divisor = actualMileage % increase
	local actual         = actualMileage % 5

	only.log('D', 'actual_divisor is :' ..tostring(actual_divisor))

	local carry_data = nil
	if actual_divisor == 0 then --十公里倍数，更新下发时间
		luakv_api.cmd('driview', accountID, 'set', accountID .. "controlFrequency", os.time())
	elseif actual == 0 then  --五公里倍数，判断是否大于两分钟并且更新时间
		local ok,value_time = luakv_api.cmd('driview', accountID, 'get', accountID .. "controlFrequency")
		if not ok or (os.time() - tonumber(value_time)) <120 then
			return false
		end
	else
		return false
	end
	--redis添加本次播放的数据
	carry_data = string.format("%s:%s:%s:%s:%s:%s", 2, 0, actualMileage , maxSpeed, avgSpeed, stopTime)
	scene.push( app_name, { ["continuousDrivingCarryData"] = carry_data } )


	return true;
end

--函数:drive_online_point
--功能:
--说明:目前只有只有疲劳驾驶应用在使用
function drive_online_point(app_name)
	local user_online_time  = supex.get_our_body_table()["T_ONLINE_HOUR"]
	local accountID         = supex.get_our_body_table()["accountID"]
	local key = accountID .. ":onlineusertime" 
	if not user_online_time then
		return false
	end
	only.log('D',"onlineTime" .. ":" .. user_online_time)
	scene.push( app_name, { ["driveOnlineHoursPoint"] = user_online_time } )
	return true
end

