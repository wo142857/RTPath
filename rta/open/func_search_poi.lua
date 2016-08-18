local only	= require('only')
local utils 	= require('utils')
local json 	= require('cjson')
local msg 	= require('msg')
local redis_api = require('redis_pool_api')
local map 	= require('map')

local url_tab = {} 

module("func_search_poi",package.seeall)
-->check incoming parameters
local function check_parameter(args)
        args["longitude"] = tonumber(args["longitude"])
        if not args["longitude"] then
                only.log('E', "requrie json have nil of \"longitude\"")
		return false
        end
        args["latitude"] = tonumber(args["latitude"])
        if not args["latitude"] then
                only.log('E', "requrie json have nil of \"latitude\"")
		return false
        end

	return true
end

-->To sort by distance
local function cmp(a,b)
        if a['distance'] < b["distance"] then
                return true
        else
                return false
        end
end

-->get all gridID
local function get_all_gridID(lon, lat)
	min_lat = math.floor(lat*100) - 2
        max_lat = math.floor(lat*100) + 2
        min_lon = math.floor(lon*100) - 2
        max_lon = math.floor(lon*100) + 2
	local grid = {}
        local i = 1
        for lon = min_lon, max_lon, 1 do
                for lat = min_lat, max_lat, 1  do
                        grid[i] = string.format("%d&%d", lon, lat)
                        i = i + 1
                end
        end
        return grid
end

--get all the POI information
local function get_all_poi(grid_key, lon, lat)
	local grid_info_key
	local success_poi = {}
	local distance = 0
	-->get all poi infomation
	for _, gridID in pairs(grid_key) do
		grid_info_key = string.format( "%s:landMark", gridID)
		only.log('D', "grid_info_key = " .. grid_info_key)
		local ok,data = redis_api.cmd('mapLandMark', '','HGETALL', grid_info_key)
		if not ok or not  data then
			local info = string.format("fail to get %s from redis %s", grid_info_key, 'mapLandMark')
			only.log('E', info)
			return false
	end
		-->Separate poitype and poi_info
		for poitype, poi_info in pairs(data) do
			local ok,map_poi_info = pcall(json.decode, poi_info)
                        if not ok then
				return false
			end
			-->get distabce and poiType
                        for k1,v1 in ipairs(map_poi_info) do
                                distance= map.get_two_point_dist(lat, lon, tonumber(v1['B']), tonumber(v1['L']))
                                v1['distance'] = distance
				v1['poiType'] = poitype
				table.insert(success_poi,v1)
                        end
                end
	end
	table.sort(success_poi,cmp)
	return success_poi
end

function handle(args)

        if not check_parameter(args) then
		return false
	end
	-->get all gridID
	local grid_key = get_all_gridID(args["longitude"], args["latitude"])
	-->get all poi
	local all_success_poi = get_all_poi(grid_key, args["longitude"], args["latitude"])
	-->get poi info by shortest distance
	local shortest_dist_poi = all_success_poi[1]
	return shortest_dist_poi
end
