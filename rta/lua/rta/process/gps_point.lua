--文件名称：gps_point.lua
--文件描述：gps点信息
--修    改：2015-06-27 重构实时里程

module("gps_point", package.seeall)

GPSPoint = {

        }

-- Return new object of GPSPoint
function GPSPoint:new()
        local self = {
                }

        setmetatable(self, GPSPoint)
        GPSPoint.__index = GPSPoint

        return self
end

--名称：writeLastPoint
--功能：写入上次gps点信息
--参数：self --> DataPackage
--返回：无
--修改：2015-07-01 重构实时里程
function GPSPoint:init(arg)
        self['longitude']    = tonumber(arg['longitude'] or 0)
        self['latitude']     = tonumber(arg['latitude'] or 0)
        self['speed']        = tonumber(arg['speed'] or 0)
        self['GPSTime']      = tonumber(arg['GPSTime'] or 0)
        self['direction']    = tonumber(arg['direction'] or -1)
	self['altitude']     = tonumber(arg['altitude'] or 0)
	self['isExtra']	     = arg['isExtra'] or false
end

