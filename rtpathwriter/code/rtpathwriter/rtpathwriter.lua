--> record: 2016-06-22,根据大数据新格式删除IMEI，IMSI，model，添加mirrtalkID, 刘勇跃

local utils		= require('utils')
local only		= require('only')
local mysql_api 	= require('mysql_pool_api')
local redis_api 	= require('redis_pool_api')
local cutils		= require('cutils')
local cjson		= require('cjson')

local g_busi_day
local next_day

local TIME_OUT		= 3600
local LIMIT_KEY		= 500
local FILE_LINE		= 300000
local TIMELIMIT		= 7200

module('rtpathwriter', package.seeall)

local function get_date_attr(date_str)
	local tb = utils.str_split(date_str, "-")

	if not tb or #tb == 0 then 
		return nil
	end

	local date_attr = {
		['year']	= tb[1],
		['month']	= tb[2],
		['day']		= tb[3],
		['hour']	= 0,
		['min']		= 0,
		['sec']		= 0,
	}

	return date_attr
end

--将时间戳转换成日期格式
local function add_date(date_str, day_count)
	local date_attr = get_date_attr(date_str)
	if not date_attr then 
		return nil
	end

	local time1 = os.time(date_attr)
	local time2 = time1 + day_count * (3600 * 24)

	return os.date("%Y-%m-%d", time2)
end

local function dispose_lastrecord(speedKey,count,file,i,j,last_key)

			local ok,lastResult = redis_api.cmd(speedKey,'','zrange',last_key,'0','-1','withscores')
			if not ok or not lastResult then
				only.log('E',"zrange values error")
				return 
			end

			if not next(lastResult) then
				return
			end
			--only.log('D',"lastResult is " .. scan.dump(lastResult))
			--only.log('D',"result" .. scan.dump(result))
			for last=1,#(lastResult) do
				--store_to_file(result[sign],file)		--固化到文件中
				tab = utils.str_split(last_key,":")
				line = string.format("%s|%s|%s|%s\n",tab[1],tab[2],lastResult[last][1],lastResult[last][2])
				--only.log('D',line)
				file:write(line)

				count = count + 1
				if count >= FILE_LINE then
					file:close()
					i = i + 1
					file_name = string.format("/home/tyy/gps.data_%s_%03d%d",g_busi_day,j,i)
					file = io.open(file_name,"a")
					file:write("mirrtalkID|tokenCode|RRID|SGID|maxspeed|avgspeed|pointCount|oneLevelCount|twoLevelCount|threeLevelCount|startTime|endTime|accountID|countyCode|GPSTime\n")
					count = 0
				end
	
	
					local ok,_ = redis_api.cmd(speedKey,'','del',last_key)
					if not ok then
						only.log('E',"del last_key error")
					end
			end					
end


--处理zset中未固化的数据
local function dispose_zset(speedKey,count,file,i,j)

	local del_key = {}
	local current_time = os.time() - TIMELIMIT
	local ok,score = redis_api.cmd(speedKey,'','zrangebyscore','ZSETKEY','-inf',current_time)
	if not ok then
		only.log('E',"zrangebyscore redis error")
	end

	--only.log('D',"current_time" .. scan.dump(score))

	for digit=1,#(score) do
		local ok,zset_tab = redis_api.cmd(speedKey,'','hgetall',score[digit])
		if not ok then
			only.log('D',"hgetall redis error")
			return 
		end
		
		local tab = utils.str_split(score[digit],":")
		--only.log('D',"tab1 " .. tab[1])
		
		local last_key = string.format('%s:%s:rtpath',tab[1], zset_tab['tokenCode'])
		dispose_lastrecord(speedKey,count,file,i,j,last_key)
		--only.log('D',"zset_tab " .. scan.dump(zset_tab))
		
		--local rtpath_key = string.format('%s:%s:rtpath', table['IMEI'], ret['tokenCode'])	
		local avgspeed = math.floor(tonumber(zset_tab['totalspeed'])/tonumber(zset_tab['pointCount']))
		
		--only.log('D',"avgspeed" .. avgspeed)
	
		local rangeValue = string.format("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n",
							tab[1],			
							zset_tab['tokenCode'],
							zset_tab['roadID'],
							zset_tab['maxspeed'],
							avgspeed,
							zset_tab['pointCount'],
							zset_tab['oneLevelCount'],
							zset_tab['twoLevelCount'],
							zset_tab['threeLevelCount'],
							zset_tab['startTime'],
							zset_tab['endTime'],
							zset_tab['accountID'],
							zset_tab['countyCode'],
							zset_tab['GPSTime']
							)
		--only.log('D',"rangeValue " .. rangeValue)
		file:write(rangeValue)

		count = count + 1
		if count >= FILE_LINE then
			file:close()
			i = i + 1
			file_name = string.format("/home/tyy/gps.data_%s_%03d%d",g_busi_day,j,i)
			file = io.open(file_name,"a")
			file:write("mirrtalkID|tokenCode|RRID|SGID|maxspeed|avgspeed|pointCount|oneLevelCount|twoLevelCount|threeLevelCount|startTime|endTime|accountID|countyCode|GPSTime\n")
			count = 0
		end


				table.insert(del_key,score[digit])
	
				if #(del_key) >= LIMIT_KEY then
					local ok,_ = redis_api.cmd(speedKey,'','del',unpack(del_key))
					--only.log('D',"unpack1 is " .. unpack(del_key))
					--only.log('D',"unpack1 is " .. scan.dump(del_key))
					if not ok then
						only.log('E',"del redis key error")
					end
					
					local ok,_ = redis_api.cmd(speedKey,'','zrem','ZSETKEY',unpack(del_key))
					--only.log('D',"unpack1 is " .. unpack(del_key))
					--only.log('D',"unpack1 is " .. scan.dump(del_key))
					if not ok then
						only.log('E',"zrem redis key error")
					end

					del_key = {}
				end
	end--for


		if next(del_key) then
			local ok,_ = redis_api.cmd(speedKey,'','del',unpack(del_key))
			--only.log('D',"zunpack2 is " .. unpack(del_key))
			--only.log('D',"zunpack2 is " .. scan.dump(del_key))
			if not ok then
				only.log('E',"finnaly del redis key error")
			end

			local ok,_ = redis_api.cmd(speedKey,'','zrem','ZSETKEY',unpack(del_key))
			--only.log('D',"unpack1 is " .. unpack(del_key))
			--only.log('D',"unpack1 is " .. scan.dump(del_key))
			if not ok then
				only.log('E',"zrem redis key error")
			end
		end
	
	return file

end


--从redis中取出需要固化的key值
local function key_from_data(g_busi_day,speedKey,j)
	
	--判断文件是否存在
	local count	= 0			--文件行数
	local i		= 1
	local file_name = string.format("/home/tyy/gps.data_%s_%03d%d",g_busi_day,j,i)
	local exist,err = io.open(file_name,"r")
	if not exist then
		file = io.open(file_name,"a")
		--file:write("IMEI|tokenCode|accountID|RRID|SGID|maxspeed|avgspeed|pointCount|oneLevelCount|twoLevelCount|threeLevelCount|createtime|startlongitude|startlatitude|endlongitude|endlatitude|RT|RS|startTime|endTime|RN|countyCode\n")
		file:write("mirrtalkID|tokenCode|RRID|SGID|maxspeed|avgspeed|pointCount|oneLevelCount|twoLevelCount|threeLevelCount|startTime|endTime|accountID|countyCode|GPSTime\n")
	else
		exist:close()
		file = io.open(file_name,"a")
	end

	--处理已经完成的数据
	local ok,ret = redis_api.cmd(speedKey,'','smembers','SETKEY')
	if not ok or not ret then
		only.log('E',"smembers redis error")
	end

	--only.log('D',"ret" .. scan.dump(ret))	

	local del_key = {}
	if next(ret) then
		for k,v in pairs(ret) do
			local ok,result = redis_api.cmd(speedKey,'','zrange',v,'0','-1','withscores')
			if not ok or not result then
				only.log('E',"hgetall values error")
				return 
			end

			--only.log('D',"result" .. scan.dump(result))
			for sign=1,#(result) do
				--store_to_file(result[sign],file)		--固化到文件中
				tab = utils.str_split(v,":")
				line = string.format("%s|%s|%s|%s\n",tab[1],tab[2],result[sign][1],result[sign][2])
				--only.log('D',line)
				file:write(line)

				count = count + 1
				if count >= FILE_LINE then
					file:close()
					i = i + 1
					file_name = string.format("/home/tyy/gps.data_%s_%03d%d",g_busi_day,j,i)
					file = io.open(file_name,"a")
					file:write("mirrtalkID|tokenCode|RRID|SGID|maxspeed|avgspeed|pointCount|oneLevelCount|twoLevelCount|threeLevelCount|startTime|endTime|accountID|countyCode|GPSTime\n")
					count = 0
				end
	
				table.insert(del_key,v)
	
				if #(del_key) >= LIMIT_KEY then
					local ok,_ = redis_api.cmd(speedKey,'','del',unpack(del_key))
					--only.log('D',"unpack1 is " .. unpack(del_key))
					--only.log('D',"unpack1 is " .. scan.dump(del_key))
					if not ok then
						only.log('E',"del redis key error")
					end
					
					local ok,_ = redis_api.cmd(speedKey,'','srem','SETKEY',unpack(del_key))
					--only.log('D',"unpack1 is " .. unpack(del_key))
					--only.log('D',"unpack1 is " .. scan.dump(del_key))
					if not ok then
						only.log('E',"srem redis key error")
					end

					del_key = {}
				end
      			end
      		end

		if next(del_key) then
			local ok,_ = redis_api.cmd(speedKey,'','del',unpack(del_key))
			only.log('D',"unpack2 is " .. unpack(del_key))
			only.log('D',"unpack2 is " .. scan.dump(del_key))
			if not ok then
				only.log('E',"finnaly del redis key error")
			end

			local ok,_ = redis_api.cmd(speedKey,'','srem','SETKEY',unpack(del_key))
			--only.log('D',"unpack1 is " .. unpack(del_key))
			--only.log('D',"unpack1 is " .. scan.dump(del_key))
			if not ok then
				only.log('E',"srem redis key error")
			end
		end
				
	end --if(ret)
		
		only.log('D',"count" .. count)
		only.log('D',"i " .. i)
		only.log('D',"j " .. j)

	--处理zset中未完成的数据
	file = dispose_zset(speedKey,count,file,i,j)


	file:close()
end


function handle()		
--	print(os.date("%Y-%m-%d-%H"))
	g_busi_day = os.date("%Y-%m-%d-%H")
	only.log('D',"g_busi_day is" ..  g_busi_day)
	for j = 1,4 do
		local speedKey = string.format("rtpath%d",j)
		only.log('D',"speedKey is " .. speedKey)
		key_from_data(g_busi_day,speedKey,j)
	end
end

handle()
