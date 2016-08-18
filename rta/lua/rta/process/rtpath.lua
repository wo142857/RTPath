--文件名称：rtpath.lua
--文件描述：实时超速
--历史记录：2016.6.21,刘勇跃,根据大坝数据新格式删除IMEI,IMSI,model，添加mirrtalkID

local redis	= require('redis_pool_api')
local luakv	= require('luakv_pool_api')
local only 	= require('only')
local utils 	= require('utils')
local cfg 	= require('cfg')
local cjson	= require('cjson')

local rate_limit = require('rate_limit')

module("rtpath", package.seeall)

--名  称：limit_speed
--功  能：判断是否超速
--参  数：rt道路等级，speed gps点的速度
--返回值：false不超速， 	1 超速10%～20%
--	  2 超速 20%～50% 	3 超速>50%
local function limit_speed(rt, speed)
	if not rt or not speed then
		return false
	end
	
	rt	= tonumber(rt)
	speed	= tonumber(speed)

	only.log('D',"speed is " .. speed)
	only.log('D',"limit is " .. rate_limit.RT_speed[rt])

	if rate_limit.RT_speed[rt] then	--TODO
		if rate_limit.RT_speed[rt]*(1+0.1) < speed and rate_limit.RT_speed[rt]*(1+0.2) >= speed then
			return 1
		elseif rate_limit.RT_speed[rt]*(1+0.2) < speed and rate_limit.RT_speed[rt]*(1+0.5) >= speed then
			return 2
		elseif rate_limit.RT_speed[rt]*(1+0.5) < speed then
			return 3
		else
			return false
		end
	else
		return false
	end
end


--名称：first_count_limit
--功能：判断imei的第一个点是否超速
--参数：RT道路等级，limitspeed gps点的速度
--返回值：one_devel,two_devel,three_devel 超速等级
local function first_count_limit(RT,limitspeed)
	
	local one_devel		= 0
	local two_devel		= 0
	local three_devel	= 0

	if limit_speed(RT,limitspeed) then
		local flag = limit_speed(RT,limitspeed)
		if flag == 1 then
			one_devel	= 1
		elseif flag == 2 then
			two_devel	= 1
		elseif flag == 3 then
			three_devel	= 1
		end
	end

	return one_devel,two_devel,three_devel
end


--名称：calculate_maxspeed
--功能：计算最大速度
--参数：luakv_speed luakv中取出的最大速度，speed gps点的速度
--返回值：新的最大速度

local function calculate_maxspeed(luakv_speed, speed)

	if tonumber(luakv_speed) > tonumber(speed) then
		return luakv_speed
	else
		return speed
	end
end


--名称：first_setto_luakv
--功能：将第一个点的信息存入luakv
--参数：gps_tab 第一个点所在的数据包,point 第一个点的数据,
--	roadID 第一个点所在的rrid与sgid,RT,imei_key 存入luakv的key值
--返回值：无
local function first_setto_luakv(gps_tab,point,roadID,info,imei_key)

	local one_devel,two_devel,three_devel = first_count_limit(RT, point['speed'])
	
	RT		= tonumber(info[5])
	countyCode	= tonumber(info[4])

	luakv.cmd('luakv', '', 'hmset', imei_key, 
		'maxspeed',		point['speed'], 
		'totalspeed',		point['speed'], 
		'pointCount',		1, 
		'oneLevelCount',	one_devel,
		'twoLevelCount',	two_devel,
		'threeLevelCount',	three_devel,
		'roadID',		roadID,
		"GPSTime",		point['GPSTime'],
		"startlongitude",	point['longitude'],
		"startlatitude",	point['latitude'],
		"endlongitude",		point['longitude'],
		"endlatitude",		point['latitude'],
		"RT",			RT,
		"RS",			rate_limit.RT_speed[RT],
		"startTime",		gps_tab['startTime'],
		"endTime",		gps_tab['endTime'],
		"tokenCode",		gps_tab['tokenCode'],
		"accountID",		gps_tab['accountID'],
		"countyCode",		countyCode
		)

	redis.cmd('rtpath', gps_tab['mirrtalkID'] or '', 'hmset', imei_key, 
		'maxspeed',		point['speed'], 
		'totalspeed',		point['speed'], 
		'pointCount',		1, 
		'oneLevelCount',	one_devel,
		'twoLevelCount',	two_devel,
		'threeLevelCount',	three_devel,
		'roadID',		roadID,
		"GPSTime",		point['GPSTime'],
		"startlongitude",	point['longitude'],
		"startlatitude",	point['latitude'],
		"endlongitude",		point['longitude'],
		"endlatitude",		point['latitude'],
		"RT",			RT,
		"RS",			rate_limit.RT_speed[RT],
		"startTime",		gps_tab['startTime'],
		"endTime",		gps_tab['endTime'],
		"tokenCode",		gps_tab['tokenCode'],
		"accountID",		gps_tab['accountID'],
		"countyCode",		countyCode
		)
	
	--local rtpath_key = string.format('%s:%s:rtpath', gps_tab['IMEI'], gps_tab['tokenCode'])	
	local rtpath_kek	= string.format('%s:rtpath', gps_tab['mirrtalkID'])
	local ok,_		= redis.cmd('rtpath',gps_tab['mirrtalkID'] or '','zadd','ZSETKEY',point['GPSTime'],rtpath_key)
	if not ok then
		only.log('E',"redis zadd error")
	end
end


--名称：data_to_redis
--功能：将一段sgid的结果存入redis
--参数：table 数据包，ret 该段sgid的信息
--返回值：无
local function data_to_redis(table,ret,tokeFlag)

	only.log('D',string.format("data_to_redis1 = %s", scan.dump(table)))
	only.log('D',string.format("data_to_redis2 = %s", scan.dump(ret)))

	--local rtpath_key = string.format('%s:%s:%s:rtpath', table['IMEI'], ret['roadID'], os.date('%Y%m%d', ret['GPSTime']))	
	local rtpath_key = string.format('%s:%s:rtpath', table['mirrtalkID'], ret['tokenCode'])	
	local avgspeed = math.floor(tonumber(ret['totalspeed'])/tonumber(ret['pointCount']))
	
	only.log('D',"rtpath_key: " .. rtpath_key)
	only.log('D',"avgspeed: " .. avgspeed)

	--道路信息存入redis
--	local ok,_ = redis.cmd('rtpath', table['IMEI'] or '', 'hmset', rtpath_key, 
--		'maxspeed', ret['maxspeed'], 
--		'avgspeed', avgspeed, 
--		'pointCount', ret['pointCount'], 
--		'oneLevelCount', ret['oneLevelCount'],
--		'twoLevelCount', ret['twoLevelCount'],
--		'threeLevelCount', ret['threeLevelCount'],
--		"startlongitude",ret['startlongitude'],
--		"startlatitude",ret['startlatitude'],
--		"endlongitude",ret['endlongitude'],
--		"endlatitude",ret['endlatitude'],
--		"RT",ret['RT'],
--		"RS",ret['RS'],
--		"startTime",ret['startTime'],
--		"endTime",ret['endTime'],
--		"tokenCode",ret['tokenCode'],
--		"accountID",ret['accountID'],
--		"countyCode",ret['countyCode'])

	local rangeValue = string.format("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s",
						ret['roadID'],
						ret['maxspeed'],
						avgspeed,
						ret['pointCount'],
						ret['oneLevelCount'],
						ret['twoLevelCount'],
						ret['threeLevelCount'],
--						ret['startlongitude'],
--						ret['startlatitude'],
--						ret['endlongitude'],
--						ret['endlatitude'],
--						ret['RT'],
--						ret['RS'],
						ret['startTime'],
						ret['endTime'],
						ret['accountID'],
						ret['countyCode']
						)

	local ok,_ = redis.cmd('rtpath',table['mirrtalkID'] or '','zadd',rtpath_key,ret['GPSTime'],rangeValue)
	if not ok then
		only.log('E',"redis hmset error")
	end

	if tokeFlag then
		local ok,_ = redis.cmd('rtpath',table['mirrtalkID'] or '','sadd','SETKEY',rtpath_key)
		if not ok then
			only.log('E',"redis sadd error")
		end
	end
end


--名称：handle_zero_speed
--功能：处理速度为零时的数据包
--参数：point 速度为零的点的信息 table gps数据包
--返回值：无
local function handle_zero_speed(point,table)

	local imei_key = string.format('%s:rtpath', table['mirrtalkID'])
	--only.log('D',"roadID " .. roadID)
	--only.log('D',"imei_key " .. imei_key)

	local ok, ret = luakv.cmd('luakv', '', 'hmget', imei_key,'maxspeed','totalspeed','pointCount','oneLevelCount','twoLevelCount','threeLevelCount','roadID','GPSTime','startlongitude','startlatitude','endlongitude','endlatitude','RT','RS','startTime','endTime','tokenCode','accountID','countyCode')
	
	if not ok then
		only.log('E',"luakv is error")
		return 
	end


	if not next(ret) then		--首次IMEI
		luakv.cmd('luakv', '', 'hmset', imei_key, 
			'maxspeed', 0, 
			'totalspeed', 0, 
			'pointCount', 1, 
			'oneLevelCount', 0,
			'twoLevelCount',0,
			'threeLevelCount',0,
			'roadID', "",
			"GPSTime",point['GPSTime'],
			"startlongitude",point['longitude'],
			"startlatitude",point['latitude'],
			"endlongitude",point['longitude'],
			"endlatitude",point['latitude'],
			"RT","",
			"RS","",
			"startTime",table['startTime'],
			"endTime",table['endTime'],
			"tokenCode",table['tokenCode'],
			"accountID",table['accountID'],
			"countyCode","")
	else
		luakv.cmd('luakv', '', 'hmset', imei_key, 
			"GPSTime",point['GPSTime'],
			"endlongitude",point['longitude'],
			"endlatitude",point['latitude'],
			"startTime",table['startTime'],
			"endTime",table['endTime'],
			"tokenCode",table['tokenCode'],
			"accountID",table['accountID'])
	end


	local rtpath_key = string.format('%s:%s:rtpath', table['mirrtalkID'], table['tokenCode'])	
	local ok,_ = redis.cmd('rtpath',table['mirrtalkID'] or '','zadd','ZSETKEY',point['GPSTime'],rtpath_key)
	if not ok then
		only.log('E',"redis zadd error")
	end

end

--名称：calculate_overspeed
--功能：计算超速信息并存到redis中
--参数：table gps数据包
--返回值：无

local function calculate_overspeed(table)

	for k, v in pairs(table.points) do
	repeat	
		if v['direction'] == -1 or v['speed'] == 0 then
--			handle_zero_speed(v,table)
		else
--			only.log('D', string.format("source_data = %s", scan.dump(v)))
			local ok, info = redis.cmd('match_road', '', 'hmget', 'MLOCATE', 
						table['mirrtalkID'], v['longitude'], v['latitude'], v['direction'],
						v['altitude'], v['speed'], table['endTime']
						)

			if not ok or not next(info) then
				only.log('E',"match road error")
				break
			end
		
			only.log('D', string.format("match road info is ", scan.dump(info)))
--			for k, v in pairs(info) do
--				if k < 6 then
--					info[k] = tonumber(info[k])
--				end
--			end
	
			local roadID	= string.format('%d|%03d', tonumber(info[1]), tonumber(info[2]))
			local imei_key	= string.format('%s:rtpath', table['mirrtalkID'])
			--only.log('D',"roadID " .. roadID)
			--only.log('D',"imei_key " .. imei_key)
	
			local ok, ret = luakv.cmd('luakv', '', 'hmget', imei_key,
						'maxspeed', 'totalspeed', 'pointCount', 'oneLevelCount',
						'twoLevelCount', 'threeLevelCount', 'roadID', 'GPSTime',
						'startlongitude', 'startlatitude', 'endlongitude', 'endlatitude',
						'RT', 'RS', 'startTime', 'endTime', 'tokenCode', 'accountID', 'countyCode'
						)
			
			if not ok or not ret then
				only.log('E',"luakv is error")
				break
			end
	
			if not next(ret) then		--首次IMEI
				first_setto_luakv(table,v,roadID,info,imei_key)	
				break
			else
				ret['maxspeed']		= tonumber(ret[1])
				ret['totalspeed']	= tonumber(ret[2])
				ret['pointCount']	= tonumber(ret[3])
				ret['oneLevelCount']	= tonumber(ret[4])
				ret['twoLevelCount']	= tonumber(ret[5])
				ret['threeLevelCount']	= tonumber(ret[6])
				ret['roadID']		= ret[7]
				ret['GPSTime']		= tonumber(ret[8])
				ret['startlongitude']	= ret[9]
				ret['startlatitude']	= ret[10]
				ret['endlongitude']	= ret[11]
				ret['endlatitude']	= ret[12]
				ret['RT']		= tonumber(ret[13])
				ret['RS']		= tonumber(ret[14])
				ret['startTime']	= tonumber(ret[15])
				ret['endTime']		= tonumber(ret[16])
				ret['tokenCode']	= ret[17]
				ret['accountID']	= ret[18]
				ret['countyCode']	= ret[19]
			end
	
			only.log('D', string.format("first_results is %s", scan.dump(ret)))
			if ret['tokenCode'] == table['tokenCode'] then	--判断和上一个tokeCode是否相同
				if ret['roadID'] == roadID then		--未驶出道路，结果保存到luakv
					pointCount	= ret['pointCount'] + 1
					totalspeed	= ret['totalspeed'] + v['speed']
					maxspeed	= calculate_maxspeed(ret['maxspeed'], v['speed'])
					if limit_speed(info[5], v['speed']) then
						local flag = limit_speed(info[5], v['speed'])
						if flag == 1 then
							ret['oneLevelCount'] = ret['oneLevelCount'] + 1
						elseif flag == 2 then
							ret['twoLevelCount'] = ret['twoLevelCount'] + 1
						elseif flag == 3 then
							ret['threeLevelCount'] = ret['threeLevelCount'] + 1
						end
					end
	
					local ok,_ = luakv.cmd('luakv', '', 'hmset', imei_key, 
							'maxspeed',		maxspeed, 
							'totalspeed',		totalspeed, 
							'pointCount',		pointCount, 
							'oneLevelCount',	ret['oneLevelCount'], 
							'twoLevelCount',	ret['twoLevelCount'], 
							'threeLevelCount',	ret['threeLevelCount'], 
							'roadID',		roadID,
							"GPSTime",		v['GPSTime'],
							"endlongitude",		v['longitude'],
							"endlatitude",		v['latitude'],
							"RT",			info[5],
							"RS",			rate_limit.RT_speed[info[5]],
							"endTime",		table['endTime'],
							"tokenCode",		table['tokenCode'],
							"accountID",		table['accountID'],
							"countyCode",		info[4]
							)

					local ok,_ = redis.cmd('rtpath', table['mirrtalkID'] or '', 'hmset', imei_key, 
							'maxspeed',		maxspeed, 
							'totalspeed',		totalspeed, 
							'pointCount',		pointCount, 
							'oneLevelCount',	ret['oneLevelCount'], 
							'twoLevelCount',	ret['twoLevelCount'], 
							'threeLevelCount',	ret['threeLevelCount'], 
							'roadID',		roadID,
							"GPSTime",		v['GPSTime'],
							"endlongitude",		v['longitude'],
							"endlatitude",		v['latitude'],
							"RT",			info[5],
							"RS",			rate_limit.RT_speed[info[5]],
							"endTime",		table['endTime'],
							"tokenCode",		table['tokenCode'],
							"accountID",		table['accountID'],
							"countyCode",		info[4]
							)
					
					if not ok then
						only.log('E',"luakv roadID1 error")
						break
					end

					local ok,_ = redis.cmd('rtpath',table['mirrtalkID'] or '','zadd','ZSETKEY',v['GPSTime'],imei_key)
					if not ok then
						only.log('E',"redis zadd error")
					end
	
				else					--驶出道路，结果存入redis
					only.log('D',"+++++++++++++++++" .. scan.dump(ret))
					
					local tokeFlag = false
					first_setto_luakv(table,v,roadID,info,imei_key)	
					data_to_redis(table,ret,tokeFlag)
	
				end
			else
				local tokeFlag = true
				first_setto_luakv(table,v,roadID,info,imei_key)	
				data_to_redis(table,ret,tokeFlag)
			end--if tokenCode
		end --if
	until true
	end
end

function handle(table)
	only.log('D', string.format('table = %s', scan.dump(table)))
	calculate_overspeed(table)
end
