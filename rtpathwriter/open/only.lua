local cfg = require('cfg')

module('only', package.seeall)

--[[=================================LOG FUNCTION=======================================]]--
local logLV = {
	D = {1, "LOG_ON-OFF_DEBUG",     "[DEBUG]"       },
	I = {2, "LOG_ON-OFF_INFO",      "[INFO]"        },
	W = {3, "LOG_ON-OFF_WARN",	"[WARN]"	},
	E = {4, "LOG_ON-OFF_ERROR",     "[ERROR]"       },
	S = {9, "LOG_ON_SYSTEM",        "[SYSTEM]"      },

	verbose = cfg["LOGLV"],
}


function log(lv, msg)
	if logLV[ lv ][1] < logLV["verbose"] then return end
	local lg = string.format("%s %s-->%s\n\n", os.date('%Y%m%d_%H%M%S'), logLV[ lv ][3], tostring(msg))
	local LOG_FILE = os.getenv ("LOG_FILE") -- get string ENV
	if not LOG_FILE then
		io.write(lg)
	else
		local fd = assert(io.open(LOG_FILE .. '_' .. os.date('%Y%m') .. '.log', "a"))
		fd:write(lg .. '\n')
		fd:close()
	end
end

