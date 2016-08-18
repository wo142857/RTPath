local only  = require('only')
--local gosay = require('gosay')
--local safe = require('safe')
--local ngx = require('ngx')
local json = require('cjson')
local msg = require('msg')
local redis_name='mapGPSData'
local redis_api = require 'redis_pool_api'

module("func_add_grid_info",package.seeall)

local function  set_redis(key,value)
        local ok, status = redis_api.cmd(redis_name, '', 'set', key ,value) --FIXME
        only.log('D',string.format("set details key = %s value = %s",key, value))
        if not status then
                only.log('E', string.format("fail to redis set value:%s",value))
        else
                only.log('D',string.format("sucess to redis set value:%s",value))
        end
end

local function get_redis(key)
        local ok, data = redis_api.cmd(redis_name, '', 'get', key)
        if not ok then
                only.log('E', string.format("fail to redis get value of key:%s",key))
        end
        return data
end

local function hset_redis(key,field,value)
	local ok,data=redis_api.cmd(redis_name, '','hset',key,field,value)
	if not ok then
                only.log('E', string.format("fail to redis hset key:%s field:%s value:%s",key,field,value))
	end
end


local function hget_redis(key,field)
	local ok,data=redis_api.cmd(redis_name,'', "HGET",key,field)
	if not ok then
                only.log('E', string.format("fail to redis hset key:%s field:%s value:%s",key,field,value))
	end
	return data;
end


local function add_set_redis(key,value)
	local ok,status=redis_api.cmd(redis_name,'','SADD',key,value)
	if not  ok then
		only.log('E',string.format("fail to redis sadd key:%s value:%s",key,value))
	end
end


local function move_set_redis(fromkey,tokey,value) 
	local ok,status = redis_api.cmd(redis_name,'','SMOVE',fromkey,tokey,value)
	if not ok then
		only.log('E',string.format("fail to redis move fromkey:%s tokey:%s value:%s",fromkey,tokey,value))
	else
		only.log('D',string.format("SMOVE %s %s %s",fromkey,tokey,value))
	end
end

local function checkparametr(args)
	local longitude =tonumber( args['longitude']) 
	if not longitude then return false  end

	local latitude =tonumber( args['latitude']) 
	if not latitude  then return false end

	local time =tonumber( args['time']) 
	if not time then return false end

	if not args['accountID'] then return false end

	return true 
end


function entry(args)
        -->>check parameter
	if not checkparametr(args) then
		only.log('E',"get parameter error")
		return 
	end 
	-->> update_grid_account_id_info	
	local lon = args["longitude"]
	local lat = args["latitude"]
	args["gridID"] = string.format("%d&%d", math.floor(lon*100), math.floor(lat*100))

        local accountkey=string.format("%s:info",args["accountID"]);
        local data=hget_redis(accountkey,"gridID");
        local gridKey=string.format("%s:accountIds",args["gridID"]);
	
	local ok,_ = redis_api.cmd(redis_name,'','hmset',accountkey,
		"longitude",args["longitude"],
		"latitude",args["latitude"],
		"time",args["time"],
		"model",args["model"],
		"imei",args["imei"])

	if not ok then
                only.log('E', string.format("fail to redis hset key:%s ", accountkey))
	end

        if not data then
        	hset_redis(accountkey,"gridID",args["gridID"])
                add_set_redis(gridKey,args["accountID"])
        else
                if data ~= args["gridID"] then
                        local oldGridKey=string.format("%s:accountIds",data)
			only.log("D",string.format("oldGridKey:%s gridKey:%s accountID:%s",oldGridKey,gridKey,args["accountID"]))
                        move_set_redis(oldGridKey,gridKey,args["accountID"])
        		hset_redis(accountkey,"gridID",args["gridID"])
                end
        end

end



