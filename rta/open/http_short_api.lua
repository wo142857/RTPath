-- auth: baoxue
-- date: Wed May 15 10:05:29 CST 2013
local socket = require('socket')
local string = require('string')
local utils = require('utils')
local only = require('only')


module('http_short_api', package.seeall)


local ERRORINFO_TAB = {}

local function http_send(socketfd, data)
        local len = #data
        local leav_len = len
        local send_data = data
        repeat
                local bytes,err = socketfd:send(send_data)
                if not bytes then
                        local log = string.format("[[%s]]Fail to send data---->%s", tostring(err), data)
                        only.log("I", log)

                        return false,err
                end
                leav_len = leav_len - tonumber(bytes)
                if leav_len ~= 0 then
                        send_data = string.sub(send_data, bytes + 1, -1)
                end
	until leav_len == 0
	return len
end

local function http_receive(socketfd)
	local len
	local result = ""
        repeat
		-->> '*a' is block to receive until tcp close
		-->> we can use '*a' by set timeout,it will back by closed or timeout
                local info, err = socketfd:receive('*l')
                if not info then
                    only.log("I", string.format("[[%s]]Fail to receive a line", err))

                    local broken_cnt = string.find(err, "^closed$")
                    if broken_cnt then
                    return result
                    end

                    local timeout_cnt = string.find(err, "^timeout$")
                    if timeout_cnt then
                    return result
                    end
                    return err
                end
            --only.log("D", "part back data ---->" .. info)
            result = result .. info .. "\r\n"
            local _st,_ed = string.find(info, "^Content%-Length%:%s-%d+$")
            if _st then
                _st,_ed = string.find(info, "%d+")
                len = string.sub(info, _st, _ed)
            end
	until info == "" and len
	if len then
                local info,err = socketfd:receive(len)
                if not info then
                        only.log("D", string.format("[[%s]]Fail to receive %s bytes", tostring(err), len))

                        local break_cnt = string.find(err, "^closed$")
                        if break_cnt then
                                return false, err
                        end
                        return err
                end
            ----only.log("D", "part back data ---->" .. info)
            result = result .. info
            ----only.log("I", "all back data ---->" .. result)
	end

	return result
end

function http(cfg, data, if_recv, max_timeout )
        local tcp = socket.tcp()
        if tcp == nil then
            only.log("E", 'load tcp failed')
            return nil
        end
        tcp:settimeout( max_timeout or 2000)
        local ret = tcp:connect(cfg["host"], cfg["port"])
        if ret == nil then
            tcp:close()
            only.log("E", string.format('Fail to connect to %s:%s', cfg["host"], cfg["port"]))
        return nil
        end

        local ret,err = http_send(tcp, data)
        if (if_recv ~= false) and ret then
            ret,err= http_receive(tcp)
        end
        tcp:close()
        --tcp:shutdown('both')
        -->> check resp
        if not ret then
                only.log("I", string.format("<--Get %s from service %s:%d-->\n", tostring(err), cfg["host"], cfg["port"]))
                return nil
        else
                return ret
        end
end


---- transit TIMEOUT protect self
---- 全局变量ERRORINFO_TAB
function http_ex(cfg, data, if_recv, pro_name , pro_ignore_time)

    ---- 默认值
    if not pro_name then pro_name = "DEFAULT_PRO_NAME" end
    if not pro_ignore_time then pro_ignore_time = 60 end

    if ERRORINFO_TAB[pro_name] then
        if (tonumber(ERRORINFO_TAB[pro_name]) or 0) > 0 and  os.time() -  (tonumber(ERRORINFO_TAB[pro_name]) or 0 ) < pro_ignore_time then
            only.log("D",string.format('ignore , pre connect failed:%s \t %s ',  ERRORINFO_TAB[pro_name] , pro_name )  )
            return nil
        end
    end

    local tcp = socket.tcp()
    if tcp == nil then
        only.log("E", 'load tcp failed')
        ERRORINFO_TAB[pro_name] = os.time()
        return nil
    end

    tcp:settimeout(300)
    local ret = tcp:connect(cfg["host"], cfg["port"])
    if ret == nil then
        tcp:close()
        only.log("E", string.format('http_ex Fail to connect to %s:%s pls waite %s  s', cfg["host"], cfg["port"] , pro_ignore_time ) )
        ERRORINFO_TAB[pro_name] = os.time()
        return nil
    end
    
    local ret,err = http_send(tcp, data)
    if (if_recv ~= false) and ret then
        ret,err= http_receive(tcp)
    end
    tcp:close()
    --tcp:shutdown('both')
    -->> check resp
    if not ret then
            only.log("I", string.format("<--Get %s from service %s:%d-->\n", tostring(err), cfg["host"], cfg["port"]))
            ERRORINFO_TAB[pro_name] = os.time()
            return nil
    else
            return ret
    end
end


function tcp(cfg, data)
    local tcp = socket.tcp()
    if tcp == nil then
        only.log("E", 'load tcp failed')
        return nil
    end
    tcp:settimeout(10000)
    local ret = tcp:connect(cfg["host"], cfg["port"])
    if ret == nil then
        tcp:close()
        only.log("E", string.format('Fail to connect to %s:%s', cfg["host"], cfg["port"]))
        return nil
    end
    ret = tcp:send(data)
    tcp:close()
    return ret
end
