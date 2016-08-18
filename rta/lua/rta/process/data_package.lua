--文件名称：data_package.lua
--文件描述：GPS数据包类，对gps数据包进行处理
--修    改：2015-06-27 重构实时里程
--	    2016-06-21 删除IMEI，IMSI，model，添加mirrtalkID，刘勇跃

local utils	= require('utils')
local scan	= require('scan')
local only	= require('only')

local redis_api = require('redis_pool_api')
local cachekv	= require('cachekv')
local luakv_api	= require('luakv_pool_api')

local GPSPointModule	= require("gps_point")
local GPSPoint		= GPSPointModule.GPSPoint

module('data_package', package.seeall)

DataPackage = {
	mirrtalkID,	--mirrtalkID设备号	
	accountID,	--账号	
	tokenCode,	--一次开关及标识
	isFirst,	--是否是开机数据， true：是；false：不是	
	isDelay,	--是否是先发后至数据，true: 是；false:不是
	lastTokenCode,	--上一次开机tokenCode	
	points,		--array：GPSPoint	gps点数组	
	lastPoint,	--table：GPSPoint	上个包gps数据	
	startTime,	--开机时间	
	endTime,	--最后时间	
}

-- Return new object of DataPackage
function DataPackage:new(mirrtalkID, accountID, tokenCode)
	local self = {}

	setmetatable(self, DataPackage)

	DataPackage.__index	= DataPackage
	self['mirrtalkID']	= mirrtalkID
	self['tokenCode']	= tokenCode
	self['accountID']	= accountID
	self['isDelay']		= false

	return self
end

--获取上次最后一个点
function DataPackage:get_last_point()
	--TODO luakv
	local last_point_key	= string.format("%s:lastPoint", self['mirrtalkID'])
	local ok, ret		= luakv_api.cmd('localRedis', self['mirrtalkID'] or '', "hmget", last_point_key, 
					'GPSTime', 'longitude', 'latitude', 'direction', 'speed', 'altitude'
					)

	if not ok or not ret or (#ret ~= 6) then
		only.log('W', "get_last_point error!")
		return nil
	end

	local last_point = GPSPoint:new()
	last_point:init{
			GPSTime		= ret[1],
			longitude	= ret[2],
			latitude	= ret[3],
			direction	= ret[4],
			speed		= ret[5],
			altitude	= ret[6]
			}

	return last_point
end

--保存当前最新点
function DataPackage:set_last_point(last_point)
	--TODO luakv
	local last_point_key	= string.format("%s:lastPoint", self['mirrtalkID'])
	local ok,_		= luakv_api.cmd('localRedis', self['mirrtalkID'] or '',  "hmset", last_point_key, 
					'GPSTime', last_point['GPSTime'], 
					'longitude', last_point['longitude'], 
					'latitude', last_point['latitude'], 
					'direction', last_point['direction'],
					'speed', last_point['speed'],
					'altitude', last_point['altitude']
					)

	if not ok then
		only.log('E', "set last point error!")
	end
end

--检查上次最新tokenCode与当前tokenCode是否相同，若不相同，则更新tokenCode
function DataPackage:checkLastTokenCode()
	--> TODO cachekv
	local token_key = string.format("%s:tokenCode", self['mirrtalkID'])	

	--> 获取上次tokenCode
	local ok,last_tokenCode = cachekv.pull('owner', self['mirrtalkID'] or '',  "get", token_key)

--	only.log('D', "last tokencode:%s, cur_tokenCode:%s", last_tokenCode or 'nil', self['tokenCode'])

	--> 若没有获取或者当前tokenCode与上次不相同，则认为是刚开机
	if not ok or not last_tokenCode then
		self['isFirst']		= true
		self['lastTokenCode']	= nil

		--保存当前tokenCode
		local ok,_ = cachekv.push('owner', self['mirrtalkID'] or '',  "set", token_key, self['tokenCode'])
		if not ok then
			only.log('E', "set last tokenCode failed!,mirrtalkID:%s, tokenCode:%s", self['mirrtalkID'], self['tokenCode'])
		end
	else
		if last_tokenCode == self['tokenCode'] then
			self['isFirst']		= false
			self['lastTokenCode']	= nil
		else
			self['isFirst']		= true
			self['lastTokenCode']	= last_tokenCode

			local ok,_ = cachekv.push('owner', self['mirrtalkID'] or '',  "set", token_key, self['tokenCode'])
			if not ok then
				only.log('E', "set last tokenCode failed!,mirrtalkID:%s, tokenCode:%s", self['M'], self['tokenCode'])
			end
		end
	end
end

function DataPackage:parseBody(points, gps_body, extra_flag)
	local time_array	= gps_body['GPSTime']
	local lon_array		= gps_body['longitude']
	local lat_array		= gps_body['latitude']
	local dir_array		= gps_body['direction']
	local speed_array	= gps_body['speed']
	local alt_array		= gps_body['altitude']

	if not time_array or #time_array == 0 then
		return nil, nil 
	end
	
	local start_time, end_time

	for i=1, #time_array do
	repeat
		--补传去重
		if extra_flag and self['lastPoint'] and tonumber(time_array[i]) <= self['lastPoint']['GPSTime'] then
			break -- continue
		end

		local p_gps = GPSPoint:new()
		p_gps:init{
			GPSTime		= time_array[i],
			longitude	= lon_array[i],
			latitude	= lat_array[i],
			speed		= speed_array[i],
			direction	= dir_array[i],
			altitude	= alt_array[i],
			isExtra		= extra_flag
		}

		points[time_array[i]] = p_gps

		if (not start_time) or (start_time > time_array[i]) then
			start_time = time_array[i]
		end

		if (not end_time) or (end_time < time_array[i]) then
			end_time = time_array[i]
		end
	until true
	end

	return start_time, end_time
end

function DataPackage:init(req_body)

	self:checkLastTokenCode()

	if not self['isFirst'] then --开机第一个包不取上次最新点
		self['lastPoint'] = self:get_last_point()
	end

	local points = {}
	local start_time, end_time	= nil,nil
	local s1, e1, s2, e2		= nil,nil,nil,nil
	
	if req_body['extragps'] then	--解析补传数据
		s1,e1 = self:parseBody(points, req_body['extragps'], true)
	end

	s2,e2 = self:parseBody(points,req_body,false)	--解析实时数据
	
	if s1 and s2 then
		start_time = math.min(s1,s2)
	else
		start_time = s1 or s2
	end

	if e1 and e2 then
		end_time = math.max(e1,e2)
	else
		end_time = e1 or e2
	end

	if not start_time or not end_time then
		return false
	end

	local drive_time = end_time - start_time
	if drive_time < 0 or drive_time > 300 then
		only.log('E', "drive time error, start:%s, end:%s", start_time, end_time)
	end

	local points_array = {}
	for i = start_time, end_time do
		table.insert(points_array, points[i])	
	end

	if not points_array or #points_array == 0 then
		return false
	end

	self['points'] = points_array

	self['startTime']	= start_time
	self['endTime']		= end_time

	if self['endTime'] and self['lastPoint'] and self['endTime'] <= self['lastPoint']['GPSTime'] then
		return false
	end

	self:set_last_point(points_array[#points_array])
	return true
end
