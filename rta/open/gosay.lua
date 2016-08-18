local supex = require('supex')

module('gosay', package.seeall)


function resp(status, data)
	local afp = supex.rgs( status )
	supex.say(afp, data)
	return supex.over(afp)
end


function resp_msg(msg, result)
    local out_msg, info
    if not result then
        info = msg[2]
    else
        info = string.format(msg[2], result)
    end

    local star = string.sub(info, 1, 1)
    if star == '[' or star == '{' then
        out_msg = string.format('{"ERRORCODE":"%s", "RESULT":%s}', msg[1], info )
    else
        out_msg = string.format('{"ERRORCODE":"%s", "RESULT":"%s"}', msg[1], info )
    end
    
    resp(200, out_msg)
    return
end
