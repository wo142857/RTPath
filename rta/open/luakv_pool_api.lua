local luakv =   require('luakv')
local link =    require('link')
local log =     require('lualog')
local scan =    require('scan')

local APP_LINK_LUAKV_LIST = link["OWN_POOL"]["redis"]
local LOCAL_DEFAULT = '@default_local@'
module('luakv_pool_api', package.seeall)

function init( )
        -- body
        local OWN_LUAKV_POOLS = {};

        for name in pairs(APP_LINK_LUAKV_LIST) do
                -- OWN_LUAKV_POOLS[name] = luakv.create();
                local hdlptr = _G.search_kvhandle(name);
                if not hdlptr then
                        log.writeall('E', "can't get handle of libkv by %s", name);
                        break;
                end
                OWN_LUAKV_POOLS[name] = luakv.createbyptr(hdlptr);
                if not OWN_LUAKV_POOLS[name] then
                        log.writeall('E', "can't create handle of libkv by %s", name);
                        break;
                end
        end

        --创建本地默认
        local hdlptr = _G.search_kvhandle(LOCAL_DEFAULT);
        if not hdlptr then
                log.writeall('E', "can't get handle of libkv by %s", LOCAL_DEFAULT);
        end
        
        OWN_LUAKV_POOLS[LOCAL_DEFAULT] = luakv.createbyptr(hdlptr);
        if not OWN_LUAKV_POOLS[LOCAL_DEFAULT] then
                log.writeall('E', "can't create handle of libkv by %s", LOCAL_DEFAULT);
        end

        _G["LUAKV_POOLS"] = OWN_LUAKV_POOLS;
end

--[[
@args 接受如下形式的参数
1.run('cmd keyvalue1, keyvalue2, ...')
2.run('cmd', 'keyvalue1', 'keyvalue2', ...)
3.run({{ 'cmd1', 'keyvaluse1', 'keyvaluse2', ... }, { 'cmd2', 'keyvaluse1', 'keyvaluse2', ... }, ...})
每个命令的操作子可以是字符串，也可以是数字。
@return true / false, error or table(表的形式如: { {result, ...}, { result, ... }, ... })
]]
function cmd( redname, hashkey, ... )
        local kvhdl = _G["LUAKV_POOLS"][redname];
        local ok, result = nil, nil;

        if not kvhdl then
                kvhdl = _G["LUAKV_POOLS"][LOCAL_DEFAULT];
        end

        if not kvhdl then
                log.writefull('E', "Can't get libkv-handler of %s", redname);
                return false, "can't get libkv-handler";
        end
        -- collectgarbage()

        local transresult = {
                _tonumber_ = function ( result )
                        return tonumber(result[1])
                end,

                _boolean_ = function ( result )
                        return result and true or false
                end,

                _ontrans_ = function ( result )
                        return result
                end,

                _first_ = function ( result )
                        return result[1]
                end,
        };

        local transresult = setmetatable({
                -- 以下命令结果被转换成数字
                sadd            = transresult._tonumber_,
                del             = transresult._tonumber_,
                dbsize          = transresult._tonumber_,
                incr            = transresult._tonumber_,
                incrby          = transresult._tonumber_,
                decr            = transresult._tonumber_,
                decrby          = transresult._tonumber_,
                lpush           = transresult._tonumber_,
                expire          = transresult._tonumber_,
                expireat        = transresult._tonumber_,
                pexpire         = transresult._tonumber_,
                pexpireat       = transresult._tonumber_,
                sismember       = transresult._tonumber_,
                len             = transresult._tonumber_,
                rpush           = transresult._tonumber_,
                hset            = transresult._tonumber_,
                scard           = transresult._tonumber_,

                -- 以下命令结果被转换成真假值
                set             = transresult._boolean_,
                flushdb         = transresult._boolean_,
                exists          = transresult._boolean_,
                mset            = transresult._boolean_,
                ["select"]      = transresult._boolean_,
                flushall        = transresult._boolean_,
                hmset           = transresult._boolean_,

                -- 以下命令结果被取第一个值
                get             = transresult._first_,
                echo            = transresult._first_,
                rpop            = transresult._first_,
                lpop            = transresult._first_,
                ["type"]        = transresult._first_,
                hget            = transresult._first_,

                -- 以下命令结果不被转换
                smembers        = transresult._ontrans_,
                lrange          = transresult._ontrans_,
                hmget           = transresult._ontrans_,
                srandmember     = transresult._ontrans_,
                
                --其他命令不转换

        }, { __index = transresult });

        --[[
        runcmd('set key value');
        or
        runcmd('set', 'key', 'value');
        ]]
        local runcmd = function ( ... )
                local ok, command = pcall(table.concat, {...}, ' ');

                if not ok then
                        return ok, command;
                end

                -- command = string.lower(command)
                local _, _, oper = string.find(command, '^%s*(%S+)%s*');
                -- oper = oper or '@'
                oper = string.lower(oper)
                
                local ok, value = nil, nil;
                local result = setmetatable({}, { __mode = 'kv' });
                for value in luakv.ask(kvhdl, command) do
                        result[#result + 1] = value;
                end
                --[[根据命令进行数据转换]]
                result = (transresult[oper] or transresult._ontrans_)(result);

                return result;
        end

        
        if type(...) == 'table' then
                local results = setmetatable({}, { __mode = 'kv' });
                for i, subtab in ipairs(...) do
                        if type(subtab) ~= 'table' then
                                log.writefull("E", "error args %s", scan.dump(...));
                                break;
                        end
                        ok, result = pcall(runcmd, unpack(subtab))
                        if not ok then
                                log.writefull("E", "run command %s fail : %s", 
                                        scan.dump(table.concat( subtab , " ")), result);
                                return ok, result
                        end

                        results[i] = result;
                end

                return ok, results;
        else
                ok, result = pcall(runcmd, ...);
                if not ok then
                        log.writefull("E", "run command %s fail : %s", 
                                scan.dump(table.concat( { ... } , " ")), result);
                end
                return ok, result;
        end
end