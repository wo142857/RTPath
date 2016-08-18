--- author  :   malei
--- date    :   2014-9-30


local utils                 = require('utils')
local only                  = require('only')
local map                   = require('map')
local json                  = require('cjson')
local redis_pool_api        = require ('redis_pool_api')
local link                  = require('link')
local G_get_two_point_dist  = map.get_two_point_dist
local get_dir               = map.CalculateTwoPointsAngle
local M_PI                  = 3.14159265358979324

poi_number                  = 10 --取周边POI的默认数量


raidus_poi_type = { 
    "1130101", --  自然村
    "1130102", --住宅小区
    "1130103", --工业大厦
    "1130104", --机关单位
}

module('raidus_find_poi_func_v3', package.seeall)

function get_around(lat,lon,raidus)
    local latitude = lat;
    local longitude = lon;

    local degree = (24901 * 1609) / 360.0;
    local raidusMile = raidus;    

    local dpmLat = 1 / degree;    
    local radiusLat = dpmLat * raidusMile;    
    local minLat = latitude - radiusLat;    
    local maxLat = latitude + radiusLat;    

    local mpdLng = degree * math.cos(latitude * (M_PI / 180));    
    local dpmLng = 1 / mpdLng;    
    local radiusLng = dpmLng * raidusMile;    
    local minLon = longitude - radiusLng;    
    local maxLon = longitude + radiusLng;    
    return minLat, minLon, maxLat, maxLon 
end

function grid_get(min_lat, min_lon, max_lat, max_lon)
    min_lat = math.floor(min_lat*100)
    max_lat = math.floor(max_lat*100)
    min_lon = math.floor(min_lon*100)
    max_lon = math.floor(max_lon*100)
    --min_lat, max_lat, min_lon, max_lon = math.floor(min_lat*1000),math.floor(max_lat*1000),math.floor(min_lon*1000),math.floor(max_lon*1000)
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



local function get_two_point_distance(lat1,lon1,lat2,lon2)
    local distance = G_get_two_point_dist(lat1,lon1,lat2,lon2)
    local direction = get_dir(lon1,lat1,lon2,lat2)
    return distance, direction
end

local function cmp(a,b)
    if a['dist'] < b["dist"] then
        return true
    else
        return false
    end
end

local function poi_match(lat,lon,dist,grid_key,type_number)
    local ok,map_chunk
    local success_poi = {}
    local distance,direction
    for k,v in pairs(grid_key) do 
        local ok, data = redis_pool_api.cmd('mapLandMark', '',
        'hmget', v .. ":landMark", unpack(type_number) ) 
        if not ok then
            only.log("E", "redis hmget failed!")
            return false
        end
        if not data then
            only.log("D", "no redis poi date!")
            return false
        end
        for filed, value in pairs(data) do
            local ok,map_chunk = pcall(json.decode, value)
            if not ok then
                only.log("D", "decode error !")
                return false
            end
            for k1,v1 in ipairs(map_chunk) do 
                distance, direction = get_two_point_distance(lat, lon, tonumber(v1['B']), tonumber(v1['L']))
                if distance < tonumber(dist) then
                    v1['dist'] = distance
                    v1['direction'] = direction 
                    table.insert(success_poi,v1)
                end
            end
        end
    end
    table.sort(success_poi,cmp)
    return success_poi[1]
end

function handle(tb)
    local lat       = tb['latitude'] 
    local lon       = tb['longitude']
    local radius    = tb['radius']
    local number    = tb['number']
    local poi_type 

    if not tb['positionType'] then
        poi_type = raidus_poi_type
    else
        poi_type = { tb["positionType"] }
    end

    --获取当前GPS点周围四个方向的最大最小经纬度
    local min_lat, min_lon, max_lat, max_lon = get_around(lat,lon,radius) 
    --获取当前GPS周围在raidus范围内的所有格网
    local grid_key = grid_get(min_lat, min_lon, max_lat, max_lon) 

    local tbl = poi_match(lat, lon, radius, grid_key, poi_type) --求得需要的POI

    return tbl

end

