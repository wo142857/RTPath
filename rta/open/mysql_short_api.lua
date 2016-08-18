local socket = require "socket"
local luasql = require('luasql.mysql')
local only = require('only')
local link = require('link')
local APP_LINK_MYSQL_LIST = link["OWN_DIED"]["mysql"]


module('mysql_short_api', package.seeall)

local OWN_MYSQL_SHORT = {}

-->>SELECT = "table"
-->>INSERT = "number"
-->>UPDATE = "number"
-->>AFFAIRS = "boolean"
-->>SQL_ERR = "nil"
local function mysql_api_execute(db, sql)
    local res,err = db:execute(sql)
    if not res then
        -->> when sql is error or connect is break.
        only.log("E", err)
        only.log("E", "FAIL TO DO: " .. sql)

        local break_conn = string.find(err, "LuaSQL%:%serror%sexecuting%squery%.%sMySQL%:%sMySQL%sserver%shas%sgone%saway")
        if break_conn then
            assert(false, tostring(err))
        end
        return nil
    end
    if type(res) == "number" then
        return res
    elseif type(res) == "userdata" then
        local result = {}
        local rows = res:numrows();
        for x=1,rows do
            result[x] = res:fetch({}, 'a') or {}
        end

        res:close()
        return result
    else
        only.log("E", tostring(type(res)) .. "unknow type result in mysql_api_execute(db, sql)")
        return res
    end
end

local function mysql_api_commit(db, T)
    local ok = db:setautocommit(false)
    if not ok then
        only.log("E", "affairs fail at setautocommit!")
        return false
    end

    local ret
    for i=1,#T do
        ok,ret = pcall(mysql_api_execute, db, T[i])
        if (not ok) or (not ret) then
            db:rollback()
            ok = db:setautocommit(true)
            return false
        end
        if ret == 0 then
            only.log('W', "update sql do nothing!")
        end
    end
    ret = db:commit()
    if not ret then
        only.log("E", "affairs fail at commit!")
        ok = db:setautocommit(true)
        return false
    end
    ok = db:setautocommit(true)
    if not ok then
        only.log('E', "affairs fail at set autocommit!")
        return false
    end
    return true
end

local function mysql_cmd(sqlname, cmds, ...)
    local mysql_api_list = {
        SELECT = mysql_api_execute,
        INSERT = mysql_api_execute,
        UPDATE = mysql_api_execute,
        REPLACE = mysql_api_execute,
        AFFAIRS= mysql_api_commit
    }
    cmds = string.upper(cmds)
    -- local begin = os.time()
    local ok,ret = pcall(mysql_api_list[ cmds ], OWN_MYSQL_SHORT[sqlname], ...)
    if not ok then
        only.log("E", string.format("%s |--->FAILED!", cmds))
        assert(false, nil)
    end
    -- only.log("D", "use time :" .. (os.time() - begin))
    if not ret then
        assert(false, nil)
    else
        return ret
    end
end

function cmd(sqlname, ...)
    --only.log('D', string.format("START MYSQL CMD |---> %f", socket.gettime()))
    -->> sqlname, cmd, sql
    -->> sqlname, {{cmd, sql}, {...}, ...}

    -->| STEP 1 |<--
    -->> fetch
    local mysql_info = APP_LINK_MYSQL_LIST[sqlname]
    if not mysql_info then
        only.log("E", "NO mysql named <--> " .. sqlname)
        return false,nil
    end
    only.log("D", string.format("%s mysql is on %s:%d", sqlname, mysql_info["host"], mysql_info["port"]))
    -->| STEP 2 |<--
    -->> connect
    local env = assert(luasql.mysql())
    if not env then
        return false,nil
    end
    ok,OWN_MYSQL_SHORT[sqlname] = pcall(env.connect, env, mysql_info['database'], mysql_info["user"],
    mysql_info["password"], mysql_info["host"], mysql_info["port"])
    env:close()
    if (not ok) or (not OWN_MYSQL_SHORT[sqlname]) then
        only.log("E", string.format("Failed connect mysql on %s:%s", mysql_info["host"], mysql_info["port"]))
        OWN_MYSQL_SHORT[sqlname] = nil
        return false,nil
    end
    OWN_MYSQL_SHORT[sqlname]:execute("set names utf8")
    -->| STEP 3 |<--
    -->> do cmd
    local stat,ret,err
    if type(...) == 'table' then
        ret = {}
        for i=1,#... do
            if type((...)[i]) ~= 'table' then
                only.log("E", "error args to call mysql_api.cmd(...)")
                break
            end

            stat,ret[i] = pcall(mysql_cmd, sqlname, unpack((...)[i]))

            if not stat then err = ret[i] break end
        end
    else
        stat,ret = pcall(mysql_cmd, sqlname, ...)

        if not stat then err = ret end
    end
    -->| STEP 4 |<--
    -->> close
    OWN_MYSQL_SHORT[sqlname]:close()
    OWN_MYSQL_SHORT[sqlname] = nil

    -- only.log('D', string.format("END MYSQL CMD |---> %f", socket.gettime()))
    if not stat then
        only.log("E", "failed in mysql_cmd " .. tostring(err))
        return false,nil
    end
    return true,ret
end
