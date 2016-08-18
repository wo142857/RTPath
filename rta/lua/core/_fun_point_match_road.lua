---->[ower]: baoxue
---->[time]: 2013-12-24
local only		= require('only')
local cjson		= require('cjson')
local utils		= require('utils')
local map		= require('map')
local socket		= require('socket')
local redis_api		= require('redis_pool_api')
local scan		= require("scan")
local supex 		= require('supex')
local luakv_api		= require('luakv_pool_api')

local G_LIB_TABLE_REMOVE = table.remove
local G_compute_distance_point_to_line	= map.compute_distance_point_to_line

local G_MATCH_MIN_ANGLE			= 30
local G_MATCH_MAX_DIST			= 35

module("_fun_point_match_road", package.seeall)

function direction_sub(dir1, dir2)
	local angle = math.abs(dir1 - dir2)
	return (angle <= 180) and angle or (360 - angle)
end


local function get_nexus_grid_key( lon, lat, key_format )
	local lon100 	= math.floor(lon*100)
	local lat100 	= math.floor(lat*100)
	local lon1000 	= math.floor(lon*1000)
	local lat1000 	= math.floor(lat*1000)

	local grid_lon = (lon1000 >= (lon100*10 + 5)) and (lon100*10 + 5) or (lon100*10)
	local grid_lat = (lat1000 >= (lat100*10 + 5)) and (lat100*10 + 5) or (lat100*10)
	local grid_core_lon = (grid_lon + 2.5)/1000
	local grid_core_lat = (grid_lat + 2.5)/1000
	local valid_grid_key_array = {}
	table.insert( valid_grid_key_array, string.format(key_format, grid_lon, grid_lat) )
	local max_offset = 2.5/1000 - 0.0004
	local lon_offset = math.abs( lon - grid_core_lon )
	local lat_offset = math.abs( lat - grid_core_lat )
	if lon_offset >= max_offset or lat_offset >= max_offset then
		if lon_offset >= max_offset and lat_offset >= max_offset then
			if lon < grid_core_lon and lat < grid_core_lat then
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon - 5, grid_lat) )
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon, grid_lat - 5) )
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon - 5, grid_lat - 5) )
			elseif lon < grid_core_lon and lat > grid_core_lat then
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon - 5, grid_lat) )
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon, grid_lat + 5) )
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon - 5, grid_lat + 5) )
			elseif lon > grid_core_lon and lat < grid_core_lat then
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon + 5, grid_lat) )
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon, grid_lat - 5) )
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon + 5, grid_lat - 5) )
			elseif lon > grid_core_lon and lat > grid_core_lat then
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon + 5, grid_lat) )
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon, grid_lat + 5) )
				table.insert( valid_grid_key_array, string.format(key_format, grid_lon + 5, grid_lat + 5) )
			else
				--> Nothing
			end
		else
			if lon_offset >= max_offset then
				if lon < grid_core_lon then
					table.insert( valid_grid_key_array, string.format(key_format, grid_lon - 5, grid_lat) )
				else
					table.insert( valid_grid_key_array, string.format(key_format, grid_lon + 5, grid_lat) )
				end
			end
			if lat_offset >= max_offset then
				if lat < grid_core_lat then
					table.insert( valid_grid_key_array, string.format(key_format, grid_lon, grid_lat - 5) )
				else
					table.insert( valid_grid_key_array, string.format(key_format, grid_lon, grid_lat + 5) )
				end
			end
		end
	end
	return valid_grid_key_array
end

local function point_match_road( lon, lat, dir, list, need )
	-->> parse data
	local array_lineID = {}
	local array_length = {}
	local array_angle1 = {}
	local array_angle2 = {}
	local array_B1 = {}
	local array_L1 = {}
	local array_B2 = {}
	local array_L2 = {}
	local array_roadID = {}
	local len = 0
	--only.log('D',string.format("start %.4f ",socket.gettime()))
	for _,kv_tab in ipairs( list or {} ) do
		for lineID, val in pairs( kv_tab or {} ) do
			table.insert( array_lineID, lineID )
			len = len + string.len(val) + string.len(lineID)
			--only.log('D', val)
			string.gsub( val, "([%d%.]+)|([%d%.-]+)|([%d%.-]+)|([%d%.]+)|([%d%.]+)|([%d%.]+)|([%d%.]+)|([%w%d]+)",
			function(length, angle1, angle2, B1, L1, B2, L2, roadID)
				table.insert( array_length,	length )
				table.insert( array_angle1,	angle1 )
				table.insert( array_angle2,	angle2 )
				table.insert( array_B1,		tonumber(B1) )
				table.insert( array_L1,		tonumber(L1) )
				table.insert( array_B2,		tonumber(B2) )
				table.insert( array_L2,		tonumber(L2) )
				table.insert( array_roadID,	roadID )
			end)
		end
	end
	list = nil
	collectgarbage("step")
	--only.log('D',string.format("=========%d==========", len))
	--only.log('D',string.format("stop %.4f ",socket.gettime()))

	--> check work
	if #array_lineID == 0 then
		--only.log('W', "O size valid")
		return nil
	end
	--> BL筛选
	local valid_lineID = {}
	local valid_length = {}
	local valid_angle1 = {}
	local valid_angle2 = {}
	local valid_B1 = {}
	local valid_L1 = {}
	local valid_B2 = {}
	local valid_L2 = {}
	local valid_roadID = {}

	local L_core_min = lon - 0.0003
	local L_core_max = lon + 0.0003
	local B_core_min = lat - 0.0003
	local B_core_max = lat + 0.0003
	--only.log('I', string.format("BL base point %s %s <--> %s %s", B_core_min, B_core_max, L_core_min, L_core_max))
	for i,lineID in ipairs( array_lineID ) do
		ok = array_B1[i] < array_B2[i]
		local B_node_min = ok and array_B1[i] or array_B2[i]
		local B_node_max = ok and array_B2[i] or array_B1[i]
		ok = array_L1[i] < array_L2[i]
		local L_node_min = ok and array_L1[i] or array_L2[i]
		local L_node_max = ok and array_L2[i] or array_L1[i]

		if not ( (B_node_min > B_core_max or B_node_max < B_core_min) or
			(L_node_min > L_core_max or L_node_max < L_core_min) ) then
			--only.log('D', string.format("BL keep lineID %s --> roadID %s", array_lineID[i], array_roadID[i]))
			table.insert( valid_lineID,	array_lineID[i] )
			table.insert( valid_length,	array_length[i] )
			table.insert( valid_angle1,	tonumber(array_angle1[i]) )
			table.insert( valid_angle2,	tonumber(array_angle2[i]) )
			table.insert( valid_B1,		array_B1[i] )
			table.insert( valid_L1,		array_L1[i] )
			table.insert( valid_B2,		array_B2[i] )
			table.insert( valid_L2,		array_L2[i] )
			table.insert( valid_roadID,	array_roadID[i] )
		else
			--only.log('I', string.format("BL out lineID %s --> roadID %s", array_lineID[i], array_roadID[i]))
		end
	end
	array_lineID = nil
	array_length = nil
	array_angle1 = nil
	array_angle2 = nil
	array_B1 = nil
	array_L1 = nil
	array_B2 = nil
	array_L2 = nil
	array_roadID = nil
	collectgarbage("step")
	if #valid_lineID == 0 then
		return nil
	end
	--> 方向筛选
	if dir ~= -1 then
		local i = 1
		while valid_lineID[i] do
			local angle1 = (valid_angle1[i] ~= -1) and direction_sub( dir, valid_angle1[i] ) or 360
			local angle2 = (valid_angle2[i] ~= -1) and direction_sub( dir, valid_angle2[i] ) or 360
			if angle1 <= G_MATCH_MIN_ANGLE or angle2 <= G_MATCH_MIN_ANGLE then  
				i = i + 1
				valid_length[i] = tonumber(valid_length[i])
			else
				--only.log('I', string.format("DIR out lineID %s --> roadID %s", valid_lineID[i], valid_roadID[i]))
				G_LIB_TABLE_REMOVE( valid_lineID,	i )
				G_LIB_TABLE_REMOVE( valid_length,	i )
				G_LIB_TABLE_REMOVE( valid_angle1,	i )
				G_LIB_TABLE_REMOVE( valid_angle2,	i )
				G_LIB_TABLE_REMOVE( valid_B1,		i )
				G_LIB_TABLE_REMOVE( valid_L1,		i )
				G_LIB_TABLE_REMOVE( valid_B2,		i )
				G_LIB_TABLE_REMOVE( valid_L2,		i )
				G_LIB_TABLE_REMOVE( valid_roadID,	i )
			end
		end
	end
	--> 距离筛选
	local rank_list = {}
	for i=1, #valid_lineID do
		local dist = G_compute_distance_point_to_line(valid_B1[i], valid_L1[i], valid_B2[i], valid_L2[i], lat, lon, valid_length[i])
		--only.log('I', string.format("dist is %f lineID %s --> roadID %s", dist, valid_lineID[i], valid_roadID[i]))
		if dist < G_MATCH_MAX_DIST then
			table.insert(rank_list, {i,dist})
		end
	end
	local all = #rank_list
	if all > need then
		all = need
	end
	if all <= 0 then
		return nil
	end
	--> 距离排序
	local sort_func = function(cmp1, cmp2)
		return cmp1[2], cmp2[2]
	end
	utils.safe_cntl_sort( rank_list, false, sort_func )
	--only.log('D', scan.dump(rank_list))

	--> 返回结果
	local result = {}
	if need == 1 then
		local index = rank_list[1][1]
		result = {
			lineID = valid_lineID[index],
			roadID = valid_roadID[index],
			angle1 = valid_angle1[index],
			angle2 = valid_angle2[index]
		}
	else
		for i=1,all do
			local index = rank_list[i][1]
			table.insert(result, {
				lineID = valid_lineID[index],
				roadID = valid_roadID[index],
				angle1 = valid_angle1[index],
				angle2 = valid_angle2[index]
			})
		end
		only.log('D', scan.dump(result))
	end
	return result
end

local function quick_location( lon, lat, dir, accountID, need )
	if not accountID then
		return false,nil
	end
	local ok, old_roadID = luakv_api.cmd('driview', accountID, 'get', accountID .. ':sysInternalRoadID');
	if not ok or not old_roadID then
		return false, nil
	end
	-- ERBR: export road by road
	local t1 = socket.gettime()
	local ok,array_maybe_roadID = redis_api.cmd("roadRelation", accountID, "hmget", "ERBR", old_roadID)
	local t2 = socket.gettime()
	--only.log('D', string.format("[RoadRelation][elapse = %s]\n", t2 - t1))
	if ok and (type(array_maybe_roadID) == "table") then
		table.insert(array_maybe_roadID, old_roadID)
	end
	-->> get 1/1000 grid keys
	local valid_road_grid_key_array = get_nexus_grid_key( lon, lat, "%d&%d:roadLine" )
	local valid_line_grid_key_array = {}

	-->> get 1/1000 grid line
	local valid_lineID_list = {}
	for _,key in ipairs( valid_road_grid_key_array ) do
		local ok, kv_tab = redis_api.cmd('mapRoadLine', accountID, 'hmget', key, array_maybe_roadID)
		if ok and kv_tab then
			local array_maybe_lineID = {}
			for _, val in pairs(kv_tab or {}) do
				string.gsub( val, "([%d]+)",
				function( lineID )
					table.insert( array_maybe_lineID,     lineID )
				end)
			end
			if #array_maybe_lineID > 0 then
				table.insert( valid_lineID_list, array_maybe_lineID )
				local k_new = string.gsub(key, "roadLine", "lineNode")
				table.insert( valid_line_grid_key_array, k_new )
			end
		else
			only.log('I', string.format("failed hmget %s from mapRoadLine : %s", key, kv_tab))
		end
	end
	-->> get 1/1000 grid data
	local list = {}
	setmetatable(list, { __mode = "k" })
	for idx,key in ipairs( valid_line_grid_key_array ) do
		local field_array = valid_lineID_list[ idx ]
		local ok, kv_tab = redis_api.cmd('mapLineNode', accountID, 'hmget', key, field_array)
		if ok and kv_tab and (#kv_tab > 0) then
			local temp_tab = {}
			for i,val in ipairs(kv_tab) do
				temp_tab[ field_array[i] ] = val
			end
			table.insert( list, temp_tab )
		else
			only.log('I', string.format("failed hmget %s from mapLineNode : %s", key, kv_tab))
		end
	end
	local result = point_match_road( lon, lat, dir, list, need )
	if not result then
		return false,nil
	end

	if need == 1 then
		local new_roadID = string.sub( tostring(result["lineID"]), 1, -4 )
		if new_roadID ~= old_roadID then
			local key = accountID .. ":sysInternalRoadID"
            		luakv_api.cmd('driview', accountID, 'set', key, new_roadID)
		end
	end
	return true,result
end

local function whole_location( lon, lat, dir, accountID, need )
	-->> get 1/1000 grid keys
	local valid_grid_key_array = get_nexus_grid_key( lon, lat, "%d&%d:lineNode" )

	-->> get 1/1000 grid data
	local list = {}
	setmetatable(list, { __mode = "k" })
	for _,key in ipairs( valid_grid_key_array ) do
		local ok, kv_tab = redis_api.cmd('mapLineNode', accountID or "", 'hgetall', key)
		--only.log('D', string.format("hgetall %s counts is %d", key, utils.get_sha_tab_count(kv_tab)))
		if ok and kv_tab then
			table.insert( list, kv_tab )
		else
			only.log('E', string.format("failed hgetall %s from mapLineNode : %s", key, kv_tab))
		end
	end
	local result = point_match_road( lon, lat, dir, list, need )
	if not result then
		return false,nil
	end
	if need == 1 then
		if accountID then
			local new_roadID = string.sub( tostring(result["lineID"]), 1, -4 )
			local key = accountID .. ":sysInternalRoadID"
            		luakv_api.cmd('driview', accountID, 'set', key, new_roadID)
		end
	end
	return true,result
end

function entry(direction, longitude, latitude, accountID, needs)
	-->> check args
	local dir	= tonumber(direction) or -1
	local lon 	= tonumber(longitude)
	local lat 	= tonumber(latitude)
	if (not lon) or (not lat) then return false,nil end
	local need = needs or 1

	-->> computer
	--only.log('D',string.format("quick_location start %.4f ",socket.gettime()))
	local ok, result = quick_location( lon, lat, dir, accountID, need )
	--only.log('D',string.format("quick_location stop %.4f ",socket.gettime()))
	if (not ok) or (not result) then
		--only.log('D',string.format("whole_location start %.4f ",socket.gettime()))
		ok, result = whole_location( lon, lat, dir, accountID, need )
		--only.log('D',string.format("whole_location stop %.4f ",socket.gettime()))
	end
	if result then
		setmetatable(result, { __mode = "k" })
	end
	return ok,result
end

function detail_entry(direction, longitude, latitude, accountID, fields)
	local ok, result = entry(direction, longitude, latitude, accountID, 1)
	if (ok and result) and ((not fields) or (type(fields) == "table" and #fields > 0)) then
		local key = result["roadID"] .. ":roadInfo"
		if not fields then
			local ok, kv_tab = redis_api.cmd('mapRoadInfo', accountID or "", 'hgetall', key)
			--only.log('D', string.format("hgetall %s counts is %d", key, utils.get_sha_tab_count(kv_tab)))
			if ok and kv_tab then
				for k,v in pairs(kv_tab) do
					result[ k ] = v
				end
			else
				only.log('E', "get mapRoadInfo all field failed!")
			end
		else
			local ok, kv_tab = redis_api.cmd('mapRoadInfo', accountID or "", 'hmget', key, fields)
			if ok and kv_tab and (#kv_tab > 0) then
				for i,val in ipairs(kv_tab) do
					result[ fields[i] ] = val
				end
			else
				only.log('E', string.format("get mapRoadInfo field %s failed!", cjson.encode(fields)))
			end
		end
		if result["RN"] and (result["RN"] == "NULL" or result["RN"] == "") then
			only.log('E', string.format("%s have error roadname!", result["roadID"]))
		end
	end
	if result then
		setmetatable(result, { __mode = "k" })
	end
	return ok, result
end
