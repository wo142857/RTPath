-- local conhash = require('conhash')
local sha     = require('sha1')
-- local socket  = require('socket')
local only    = require('only')
local cutils  = require('cutils')
local utils  = require('utils')
local cjson   = require('cjson')

local BASE = _G

module('app_utils', package.seeall)


GLOBAL_VAR_TAB = {}

---- 全局变量保存功能 ----begin 
function get_global_var(key)
    return GLOBAL_VAR_TAB[key]
end

function set_global_var(key,val)
    GLOBAL_VAR_TAB[key] = val
end
---- 全局变量保存功能 ----end


--
-- 通过IMEI计算hash分布
-- 目前主要用于对用户的URLLOG、GPS数据进行分片
--
IMEI_SHARDING_SIZE = 10
function get_imei_hash( imei )
    local tmp = tonumber(imei)
    if not tmp then
        only.log('E',string.format("get_imei_hash:imei format error: %s", imei))
        return nil
    end
    return imei % IMEI_SHARDING_SIZE
end

---- 计算字符串总个数 2014-12-01
---- 一个汉字算一个 jiang z.s. 
function str_count(str)
    if not str then return 0 end
    local _,chinese_len=str:gsub('[\128-\255]','')
    local _,char_len=str:gsub('[\1-\127]','')
    return char_len + chinese_len / 3 
end


---- 通过appKey获取secret 2014-11-11 jiang z.s. 
function get_secret( app_key )
    if not app_key then return nil end
    local ok, res = redis_pool_api.cmd('public', 'hget', app_key .. ':appKeyInfo', 'secret')
    if ok and res then
        return res
    end
    return nil
end

function gen_sign(T, secret)
    if not secret then
        local ok, res = redis_pool_api.cmd('public', 'hget', T['appKey'] .. ':appKeyInfo', 'secret')
        secret = res
    end

    local kv_table = {}
    for k,v in pairs(T) do
        if type(v) ~= "table" then
            if k ~= "sign" then
                table.insert(kv_table, k)
            end
        end
    end
    table.insert(kv_table, "secret")
    table.sort(kv_table)
    local sign_string = kv_table[1] .. T[kv_table[1]]
    for i = 2, #kv_table do
        if kv_table[i] ~= 'secret' then
            sign_string = sign_string .. kv_table[i] .. T[kv_table[i]]
        else
            sign_string = sign_string .. kv_table[i] .. secret
        end
    end
    only.log("D", "%s",sign_string)
    --local ngx = require('ngx')
    --local raw_sign_str = ngx.escape_uri(sign_string)
    --only.log("D", raw_sign_str)


    --local result = sha.sha1(raw_sign_str)
    local result = sha.sha1(sign_string)
    local sign_result = string.upper(result)
    only.log("D", sign_result)

    return sign_result
end

function check_accountID(accountID)
    if accountID == nil or (not utils.is_word(accountID)) or #accountID ~= 10 then
        return false
    end

    return true
end

function check_imei(imei)
    if not imei or (not utils.is_number(imei)) or (#imei~=15) or (string.sub(imei, 1, 1)=='0') then
        return false
    end

    return true
end

---- 判断是否为多媒体文件
function check_is_voice(binary, length)

end

---- 0X23 0X21 0X41 0X4D 0X52 0X0A
---- 所有AMR文件头标志是6个字节。
---- http://blog.csdn.net/dinggo/article/details/1966444
---- return
---- 1) bool  true: is amr file
---- 2) length number , amr head length 
function check_is_amr(binary, length)
    if not binary then return false end
    if not length  or tonumber(length) < 15 then return false end
    local file_title = { [1] = "#!AMR\n", [2] = "#!AMR-WB\n",[3] = "#AMR_MC1.0\n", [4] = "#AMR-WB_MC1.0\n" }
    local is_amr = false
    local head_length = 0 
    for i, v in pairs(file_title) do
        if string.sub(binary,1,#v) == v then
            is_amr = true
            head_length = #v
            break
        end
    end
    return is_amr, head_length
end

function check_is_wav(binary , length )
    if not binary then return false end
    if not length  or tonumber(length) < 15 then return false end

    local file_title = { [1] = "RIFF"}
    local is_wav = false
    for i, v in pairs(file_title) do
        if string.sub(binary,1,#v) == v then
            is_wav = true
            break
        end
    end
    return is_wav
end

function check_is_mp3( binary , length )
    if not binary then return false end
    if not length  or tonumber(length) < 1 then return false end--HAVE bug

    -- FIXME:this function is no complete, please implement it.
    return false
end




---- return value
---- 1: true / false  
---- 2: if true ,the value is file url

function txt_2_voice(dfsServer_v, appKey_v, secret_v,text_v, speed_v , announcer_v , volume_v )

    if not text_v then return false,nil end
    if #text_v < 1 then return false,nil end


    only.log('D',string.format("utils: appkey:%s  secret:%s  text: %s ", appKey_v , secret_v , text_v ))

    local  tab = {
        appKey = appKey_v,
        text   = text_v,
    }

    if speed_v then
        tab['speechRate'] = speed_v
    end

    if announcer_v then
        tab['speechAnnouncer'] = announcer_v
    end

    if volume_v and (tonumber(volume_v) or 0 ) ~= 0  then
        tab['speechVolume'] = tonumber(volume_v)
    end
    
    tab['sign'] = gen_sign(tab, secret_v)
    tab['text'] = utils.url_encode(text_v)
    local body = utils.table_to_kv(tab)
    local post_data = 'POST /dfsapi/v2/txt2voice HTTP/1.0\r\n' ..
          'Host:%s:%s\r\n' ..
          'Content-Length:%d\r\n' ..
          'Content-Type:text/plain\r\n\r\n%s'

    local req = string.format(post_data,dfsServer_v.host, tostring(dfsServer_v.port) , #body , body )
    local ok,ret = cutils.http(dfsServer_v.host, dfsServer_v.port, req, #req)
    if not ok or ret == nil then
        only.log('E',"txt to voice post txt data failed!")
        return false,nil,nil
    end

    if ret then
        local ret_str = string.match(ret,'{.+}')
        if ret_str then
            local ok_status,ok_tab = pcall(cjson.decode , ret_str )
            if ok_status and ok_tab then
                if tostring(ok_tab['ERRORCODE']) == "0" then
                    return true , ok_tab['RESULT']['url'],ok_tab['RESULT']['fileID'],ok_tab['RESULT']['fileSize']
                end
            end
        end
    end
    ----添加错误详细日志信息
    only.log('E',req)
    only.log('E',"===============txt_2_voice post succed,but return  failed!==========")
    only.log('E',ret)
    return false ,nil,nil
end


