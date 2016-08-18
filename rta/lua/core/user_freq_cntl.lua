local freq = require("freq")
local only = require("only")
local supex = require('supex')


module("user_freq_cntl", package.seeall)


function filter( app_name )
	local accountID = supex.get_our_body_table()["accountID"]
	local ok = freq.freq_filter(app_name, accountID)
	if not ok then
		only.log("D", "freq_filter false")
	end
	return ok
end

function regain( app_name )
	local accountID = supex.get_our_body_table()["accountID"]
	local ok = freq.freq_regain(app_name, accountID)
	if not ok then
		only.log("D", "freq_regain false")
	end
	return ok
end

		
function init( app_name )
	local accountID = supex.get_our_body_table()["accountID"]
	freq.freq_init( accountID )
end
