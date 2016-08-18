local only              = require('only')
local socket            = require('socket')
local supex            = require('supex')
local scan              = require('scan')
local cfg               = require('cfg')
local judge             = require('judge')
local user_freq_cntl	= require("user_freq_cntl")
local luakv_api		= require('luakv_pool_api')


module('init_data', package.seeall)




local function power_on_settings()
	local accountID = supex.get_our_body_table()["accountID"]
	--频率控制中开机记录数据初始化 
	user_freq_cntl.init( )

	--[[initialize the redis of private_hash]]
	judge.reach_another_step_init(accountID)

end

local function collect_settings()
end

local function power_off_settings()
end


function handle ( skip )
	if skip then
		return
	end
	local t1 = socket.gettime()
	if supex.get_our_body_table()["powerOn"] then
		local ok,result = pcall( power_on_settings )
		if not ok then
			only.log("E", result)
		end
	end
	if supex.get_our_body_table()["collect"] then
		local ok,result = pcall( collect_settings )
		if not ok then
			only.log("E", result)
		end
	end
	if supex.get_our_body_table()["powerOff"] then
		local ok,result = pcall( power_off_settings )
		if not ok then
			only.log("E", result)
		end
	end
	local t2 = socket.gettime()
	if(cfg["OWN_INFO"]["SYSLOGLV"]) then
		only.log('S', string.format("MODULE : init_data ===>  total [%f]", t2 - t1))
	end
end
