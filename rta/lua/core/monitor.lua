local only	= require("only")
local redis_api = require("redis_pool_api")
local socket	= require("socket")
local CFG_LIST	= require("cfg")

local ALIAS_LIST = require("ALIAS_LIST")
local ALIAS_MORE = CFG_LIST["MOD_NAME"] or {}

module("monitor", package.seeall)

--获取时间戳(精确到ms)
local function get_time_stamp()
	return socket.gettime()
end




--初始化
local MONITOR_POOL = {
	PERIOD_TIMESTAMP	= 0,			--周期开始时间
	MODULE_TIMESTAMP	= 0,			--模块执行起始时间

	TOTAL_PACKET_CNT	= 0,

	MONITOR_DETAIL_LIST	= {}
}

local function refresh_list(name)
	MONITOR_POOL["MONITOR_DETAIL_LIST"][name] = {
		timestamp	= 0,
		-- index use
		packet_grow 	= 0,
		filter_grow	= 0,
		match_grow 	= 0,
		work_grow	= 0,
		-- time use
		match_avge	= 0,
		match_peak	= 0,
		match_mini	= 0,
		work_avge	= 0,
		work_peak	= 0,
		work_mini	= 0,
	}
	only.log("D", "MONITOR: REFRESH [%s]", name)
end

local function refresh_pool()
	MONITOR_POOL["PERIOD_TIMESTAMP"] = get_time_stamp()
	MONITOR_POOL["TOTAL_PACKET_CNT"] = 0
	only.log("D", "MONITOR: REFRESH POOL")
end

--=================================================================--










function mod_bef_entry(name)
	local monitor_record = MONITOR_POOL["MONITOR_DETAIL_LIST"]
	--如果子表为空或者不存在,刷新子表
	if not next(monitor_record[name] or {}) then
		refresh_list(name)
	end
	monitor_record[name]["packet_grow"] = monitor_record[name]["packet_grow"] + 1
	only.log("D", "MONITOR: COUNT +1|%d [%s]", monitor_record[name]["packet_grow"], name)
end

function mod_end_entry(name)
end

function mod_bef_filter(name)
	local model_monitor = MONITOR_POOL["MONITOR_DETAIL_LIST"][name]
	model_monitor["filter_grow"] = model_monitor["filter_grow"] + 1
	only.log("D", "MONITOR: FILTER +1|%d [%s]", model_monitor["filter_grow"], name)
end

function mod_end_filter(name)
end

--统计match次数
function mod_bef_match(name)
	local model_monitor = MONITOR_POOL["MONITOR_DETAIL_LIST"][name]
	model_monitor["match_grow"] = model_monitor["match_grow"] + 1
	model_monitor["timestamp"] = get_time_stamp()
	only.log("D", "MONITOR: MATCH +1|%d [%s]", model_monitor["match_grow"], name)
end

--为match记时
function mod_end_match(name)
	local model_monitor = MONITOR_POOL["MONITOR_DETAIL_LIST"][name]
	local now = get_time_stamp()
	local last = now - model_monitor["timestamp"]
	model_monitor["match_avge"] = model_monitor["match_avge"] + last
	model_monitor["match_mini"] = (model_monitor["match_mini"] < last) and (model_monitor["match_mini"] ~= 0) and model_monitor["match_mini"] or last
	model_monitor["match_peak"] = (model_monitor["match_peak"] > last) and model_monitor["match_peak"] or last
end


--统计work次数
function mod_bef_work(name)
	local model_monitor = MONITOR_POOL["MONITOR_DETAIL_LIST"][name]
	model_monitor["work_grow"] = model_monitor["work_grow"] + 1
	model_monitor["timestamp"] = get_time_stamp()
	only.log("D", "MONITOR: WORK +1|%d [%s]", model_monitor["work_grow"], name)
end

--为WORK记时
function mod_end_work(name)
	local model_monitor = MONITOR_POOL["MONITOR_DETAIL_LIST"][name]
	local now = get_time_stamp()
	local last = now - model_monitor["timestamp"]
	model_monitor["work_avge"] = model_monitor["work_avge"] + last
	model_monitor["work_mini"] = (model_monitor["work_mini"] < last) and (model_monitor["work_mini"] ~= 0) and model_monitor["work_mini"] or last
	model_monitor["work_peak"] = (model_monitor["work_peak"] > last) and model_monitor["work_peak"] or last
end














--=================================================================--



local function calculate( idx )
	local extreme_store = {}
	local avgtime_store = {}
	local trigger_store = {}
	local percent_store = {}


	--是空表直接跳过(空表只会发生在启动后还没有客户接入的情况下)
	for k,v in pairs(MONITOR_POOL["MONITOR_DETAIL_LIST"]) do
		--无数据请求
		if v["packet_grow"] == 0 then
			only.log("W", "MONITOR: COUNT = 0 [%s]", k)
		end
		local name = (ALIAS_LIST["OWN_LIST"][k] or ALIAS_MORE[k] or k)
		--峰值
		local note = string.format('"%s":["%0.3f<==>%0.3f","%0.3f<==>%0.3f"]', name,
			v["match_mini"]*1000, v["match_peak"]*1000,
			v["work_mini"]*1000, v["work_peak"]*1000 )
		table.insert( extreme_store, note )
		--计算平均执行时间
		local have1 = (v["match_grow"] ~= 0)
		local have2 = (v["work_grow"] ~= 0)
		local note = string.format('"%s":[%0.3f,%0.3f]', name,
			have1 and (v["match_avge"]/v["match_grow"]) or 0,
			have2 and (v["work_avge"]/v["work_grow"]) or 0)
		table.insert( avgtime_store, note )


		--触发率
		local note = string.format('"%s":[%d,%d,%d,%d,%d]', name,
			MONITOR_POOL["TOTAL_PACKET_CNT"],
			v["packet_grow"],
			v["filter_grow"],
			v["match_grow"],
			v["work_grow"])
		table.insert( trigger_store, note )
		--计算百分比
		local all = MONITOR_POOL["TOTAL_PACKET_CNT"]
		local have = (MONITOR_POOL["TOTAL_PACKET_CNT"] ~= 0)
		local note = string.format('"%s":[%0.2f%%,%0.2f%%,%0.2f%%,%0.2f%%]', name,
			have and ((v["packet_grow"]/all) * 100) or 0,
			have and ((v["filter_grow"]/all) * 100) or 0,
			have and ((v["match_grow"]/all) * 100) or 0,
			have and ((v["work_grow"]/all) * 100) or 0)
		table.insert( percent_store, note )
		do
			if v["work_grow"] and v["work_grow"] > 0 then
				local redis_key = string.format("%s:%s:DRIVIEW_SCENE_COUNTS", os.date("%Y%m%d"),k )
					redis_api.cmd("public", "", "incrby", redis_key, v["work_grow"])
			end
		end

		--重置子表
		refresh_list(k)
	end

	local time_string = string.format('"%s","%s"',
		os.date("%Y%m%d%H%M%S", MONITOR_POOL["PERIOD_TIMESTAMP"]),
		os.date("%Y%m%d%H%M%S", os.time())
		)

	local census_extreme = string.format("[%s,{%s}]", time_string, table.concat(extreme_store, ","))
	local census_avgtime = string.format("[%s,{%s}]", time_string, table.concat(avgtime_store, ","))
	local census_trigger = string.format("[%s,{%s}]", time_string, table.concat(trigger_store, ","))
	local census_percent = string.format("[%s,{%s}]", time_string, table.concat(percent_store, ","))
	print(census_extreme)
	print(census_avgtime)
	print(census_trigger)
	print(census_percent)
	refresh_pool()
	return {
		EXTREME 	= string.gsub(census_extreme, "%%", "%%%%"),
		AVGTIME 	= string.gsub(census_avgtime, "%%", "%%%%"),
		TRIGGER 	= string.gsub(census_trigger, "%%", "%%%%"),
		PERCENT 	= string.gsub(census_percent, "%%", "%%%%")
	}
end


-->获取服务器设备号
function get_mac_address()
	local file = io.open("/etc/sysconfig/network-scripts/ifcfg-eth0", "r")
	local MAC
	for line in file:lines() do
        	if string.find(line, "IPADDR=") then
                	MAC = string.sub(line, 8, -1)                          
			break   
        	end
	end 
	file:close()
	return MAC
end


local function callback( idx )
	local census = calculate(idx)
	only.log("I", census["PERCENT"])
	only.log("I", census["AVGTIME"])

	local MACAddress = get_mac_address()
	
	redis_api.cmd("public", "", "hset", "EXTREME", MACAddress .. ":" .. tostring(idx), census["EXTREME"])
	redis_api.cmd("public", "", "hset", "AVGTIME", MACAddress .. ":" .. tostring(idx), census["AVGTIME"])
	redis_api.cmd("public", "", "hset", "TRIGGER", MACAddress .. ":" .. tostring(idx), census["TRIGGER"])
	redis_api.cmd("public", "", "hset", "PERCENT", MACAddress .. ":" .. tostring(idx), census["PERCENT"])

        redis_api.cmd("public", "", "hdel", "EXTREME", tostring(idx))
        redis_api.cmd("public", "", "hdel", "AVGTIME", tostring(idx))
        redis_api.cmd("public", "", "hdel", "TRIGGER", tostring(idx))
        redis_api.cmd("public", "", "hdel", "PERCENT", tostring(idx))

end



function mon_init()
	only.log("D", "MONITOR: INIT ...")
	redis_api.cmd("public", "", "hmset", "SCENE_KEY_LIST", "l_f_over_speed", "超速情景",
							       "l_f_home_offsite", "异地触发",
							       "e_f_power_on", "开机",
							       "e_f_power_off", "关机",
							       "onedayboot", "今天第一次开机情景",	
						               "e_f_first_boot", "历史第一次开机情景",	
							       "l_f_continuous_driving_mileage", "连续驾驶里程触发",
							       "l_f_fatigue_driving", "疲劳驾驶触发",
							       "l_f_fetch_4_miles_ahead_poi","4公里poi触发"
	)
	redis_api.cmd("public", "", "sadd", "MONITOR", "EXTREME", "AVGTIME", "TRIGGER", "PERCENT")
	redis_api.cmd("public", "", "mset", "EXTREME:EXPLAIN", '["开始时间","结束时间",{"模块名":["匹配函数用时(最小<==>最大)","执行函数用时(最小<==>最大)"]}]',
	"AVGTIME:EXPLAIN", '["开始时间","结束时间",{"模块名":["匹配函数平均用时","执行函数平均用时"]}]',
	"TRIGGER:EXPLAIN", '["开始时间","结束时间",{"模块名":["请求流量","模块流量","过滤流量","匹配流量","执行流量"]}]',
	"PERCENT:EXPLAIN", '["开始时间","结束时间",{"模块名":["模块流量率","过滤流量率","匹配流量率","执行流量率"]}]')

	refresh_pool()
end

function mon_come()
	only.log("D", "MONITOR: COME ...")

	MONITOR_POOL["MODULE_TIMESTAMP"] = get_time_stamp()
	MONITOR_POOL["TOTAL_PACKET_CNT"] = MONITOR_POOL["TOTAL_PACKET_CNT"] + 1
end


function mon_stat( idx )
	only.log("D", "MONITOR:开始统计数据")
	local ok,ret = pcall(callback, idx)
	if not ok then
		only.log("E", "MONITOR:回调执行失败" .. tostring(ret))
	end
	only.log("D", "MONITOR:结束统计数据")
end
