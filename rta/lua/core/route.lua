local cjson		= require('cjson')
local utils		= require('utils')
local scan		= require('scan')
local only		= require('only')
local supex		= require('supex')
local freq		= require('freq')

local APP_CFG		= require('cfg')
local BOOL_FUNC_LIST	= require('BOOL_FUNC_LIST')
local WORK_FUNC_LIST	= require('WORK_FUNC_LIST')

module('route', package.seeall)

DEFAULT_APP_PATH = string.format("./lua/%s/data/", supex["__SERV_NAME__"])
local OWN_APP_HOME_PATH = DEFAULT_APP_PATH
local OWN_APP_LIST_PATH = OWN_APP_HOME_PATH .. "/depot/"

--[[----------------->
	info = string.gsub(info, '{"', '{\n\t')
	info = string.gsub(info, '"}', '"\n}')
	info = string.gsub(info, '":"', ' = "')
	info = string.gsub(info, '","', '",\n\t')
--]]----------------->
--[[----------------->
local function save_one_list( t, f )
	local info = cjson.encode( t )
	only.log("D", string.format("save json data to file:%s", info))
	info = string.gsub(info, '\\/', '/')
	info = string.gsub(info, '{', '{\n\t', 1)
	info = string.gsub(info, '},', '\n\t},\n\t')
	info = string.gsub(info, '}}', '\n\t}\n}')
	info = string.gsub(info, '"([%a%_][%w%_]-)":%[(.-)%](,?)', '%1 = {\n\t\t\t%2\n\t\t}%3\n\t\t')
	info = string.gsub(info, '"([%a%_][%w%_]-)":{', '%1 = {\n\t\t')
	info = string.gsub(info, '"([%a%_][%w%_]-)":(%d+)(,?)', '%1 = %2%3\n\t\t')
	info = string.gsub(info, '"([%a%_][%w%_]-)":("..-")(,?)', '%1 = %2%3\n\t\t')
	info = string.gsub(info, '","', '",\n\t\t\t"')
	info = string.gsub(info, '\n\t-\n', '\n')

	local full = OWN_APP_LIST_PATH .. f
	local fd = io.open( full .. ".tmp", "w+")
	fd:write( string.format('module("%s")\n\n\nOWN_LIST = ', f) )
	fd:write( info )
	fd:close()
	os.execute(string.format("mv %s %s", full .. ".tmp", full .. ".lua"))
end
--]]----------------->
local function save_one_list( t, f, c )
	if not supex["_FINAL_STAGE_"] then return end

	only.log("D", string.format("save json data to file:%s", string.gsub(cjson.encode( t ), "%%", "%%%%")))
	local info = scan.dump(t)
	info = string.gsub(info, '%[%d+%][\t% ]*=[\t% ]*', '')
	if c then
		--[[--->
		info = string.gsub(info, '%{[\n\t% ]*([^\n\t,]+),[\n\t% ]*([^\n\t,]+),?[\n\t% ]*%}', '{%1,%2}')
		--[[--->
		info = string.gsub(info, '{[\n\t% ]*([^{\n\t% ]+)', '{%1')
		info = string.gsub(info, ',[\n\t% ]*([^{]+)', ',%1')
		info = string.gsub(info, ',[\n\t% ]*(},)', '%1')
		--]]--->
		info = string.gsub(info, '",([\n\t% ]*)"', '","')
		info = string.gsub(info, '%{[\n\t% ]*("[^\n\t]+"),?[\n\t% ]*%}', '{%1}')
		--]]--->
	end

	local full = OWN_APP_LIST_PATH .. f
	local fd = io.open( full .. ".tmp", "w+")
	fd:write( string.format('module("%s")\n\n\nOWN_LIST = ', f) )
	fd:write( info )
	fd:close()
	os.execute(string.format("mv %s %s", full .. ".tmp", full .. ".lua"))
end


--<[===============================TEMPLET DATA===============================]>--
OWN_TEMPLET_LIST_INFO = require('TEMPLET_LIST').OWN_LIST

function push_templet( mode, name, mark, args )
	if OWN_TEMPLET_LIST_INFO[ string.upper(mode) .. "_NAME" ][name] then
		only.log("W", "templet [" .. mode .. "<==>" .. name .. "] has exist!")
		return false
	else
		OWN_TEMPLET_LIST_INFO[ string.upper(mode) .. "_NAME" ][name] = mark
		OWN_TEMPLET_LIST_INFO[ string.upper(mode) .. "_INFO" ][name] = args
	end
	save_one_list( OWN_TEMPLET_LIST_INFO, "TEMPLET_LIST", false )
	return true
end

function pull_templet( mode, name )
	if mode and name then
		return OWN_TEMPLET_LIST_INFO[ string.upper(mode) .. "_INFO" ][name]
	end
	if (not mode) or (mode == "all") then
		return string.format('[{"name":"精准模板","value":%s},{"name":"部分模板","value":%s},{"name":"广播模板","value":%s},{"name":"点播模板","value":%s}]',
			cjson.encode( OWN_TEMPLET_LIST_INFO["EXACT_NAME"] ),
			cjson.encode( OWN_TEMPLET_LIST_INFO["LOCAL_NAME"] ),
			cjson.encode( OWN_TEMPLET_LIST_INFO["WHOLE_NAME"] ),
			cjson.encode( OWN_TEMPLET_LIST_INFO["ALONE_NAME"] ))
	else
		return cjson.encode( OWN_TEMPLET_LIST_INFO[ string.upper(mode) .. "_NAME" ] )
	end
end
--<[===============================STATUS DATA===============================]>--
local OWN_EXACT_MODE = 1
local OWN_LOCAL_MODE = 2
local OWN_WHOLE_MODE = 3
local OWN_ALONE_MODE = 4
local OWN_MODE_INDEX = {
	["exact"] = OWN_EXACT_MODE,
	["local"] = OWN_LOCAL_MODE,
	["whole"] = OWN_WHOLE_MODE,
	["alone"] = OWN_ALONE_MODE,
}

local OWN_STATUS_LIST_INFO = {
	[OWN_EXACT_MODE] = require('EXACT_APP_LIST').OWN_LIST,
	[OWN_LOCAL_MODE] = require('LOCAL_APP_LIST').OWN_LIST,
	[OWN_WHOLE_MODE] = require('WHOLE_APP_LIST').OWN_LIST,
	[OWN_ALONE_MODE] = require('ALONE_APP_LIST').OWN_LIST,
}
local OWN_STATUS_LIST_NAME = {
	[OWN_EXACT_MODE] = 'EXACT_APP_LIST',
	[OWN_LOCAL_MODE] = 'LOCAL_APP_LIST',
	[OWN_WHOLE_MODE] = 'WHOLE_APP_LIST',
	[OWN_ALONE_MODE] = 'ALONE_APP_LIST',
}

function check_status( mode, name )
	return OWN_STATUS_LIST_INFO[ mode ][ name ] and true or false
end

function load_all_app( mode, func_insmod )
	for k, v in pairs(OWN_STATUS_LIST_INFO[ mode ]) do
		if v == "open" then
			func_insmod( k, true )
		elseif v == "close" then
			func_insmod( k, false )
		end
	end
end

function make_new_app( mode, name, args, func )
	if not supex["_FINAL_STAGE_"] then return end

	-->> set head
	local head = 'local utils\t\t= require("utils")\n' ..
	'local only\t\t= require("only")\n' ..
	'local redis_api\t\t= require("redis_pool_api")\n' ..
	'local APP_CFG\t\t= require("cfg")\n' ..
	'local judge\t\t= require("judge")\n' ..
	'local supex\t\t= require("supex")\n' ..
	'local APP_CONFIG_LIST\t\t= require("CONFIG_LIST")\n' ..
	'local BOOL_FUNC_LIST\t\t= require("BOOL_FUNC_LIST")\n' ..
	'local WORK_FUNC_LIST\t\t= require("WORK_FUNC_LIST")\n\n'

	-->> set mark
	local mark = string.format('\nmodule("%s", package.seeall)\n\n', name)

	-->> set bind
	local memb = {}
	for k,v in pairs(args or {}) do
		table.insert(memb, tostring(k))
	end
	local keys = string.gsub(cjson.encode( memb ), '"position"', '"longitude","latitude"')
	local bind = string.format( 'function bind()\n\treturn \'%s\'\nend\n\n', keys )
	-->> set match
	local way = {
		["boolean"]	= function(val, key) return string.format('%s == %s', key, val) end,
		["number"]	= function(val, key) return string.format('%s == %d', key, val) end,
		["string"]	= function(val, key) return string.format('%s == "%s"', key, val) end,
		["function"]	= function(val, key)
			assert(BOOL_FUNC_LIST["OWN_LIST"][ val ], string.format("[%s] is not in BOOL_FUNC_LIST.lua", val))
			return BOOL_FUNC_LIST["OWN_LIST"][ val ]( name, key ) 
		end
	}
	local match = 'function match()\n'
    
	-->|<--
	local args_list = args or {}
	local rank_list = APP_CFG["ranklist"] or {}
	local keys_list = {}
	local vals_list = {}

	for k,v in pairs(args_list) do
		if v and (#v > 0) then
			table.insert(keys_list, v[2])
			if not vals_list[ v[2] ] then
				vals_list[ v[2] ] = {}
			end
			table.insert(vals_list[ v[2] ], {v[1], k})
		end
	end
	local sort_func = function(cmp1, cmp2)
		return rank_list[ cmp1 ] or 0, rank_list[ cmp2 ] or 0
	end
	utils.safe_cntl_sort( keys_list, true, sort_func )
	for _,f in ipairs(keys_list) do
		local all = vals_list[ f ] 
		for _,one in ipairs(all or {}) do
			local t = one[1]
			local k = one[2]
			local key = string.format( 'supex.get_our_body_table()["%s"]', tostring(k) )
			match = match .. string.format('\tif not (%s) then\n\t\treturn false\n\tend\n', way[ t ]( f, key ))
		end
	end
	-->|<--
	match = match .. '\treturn true\nend\n\n'
	-->> set work
	local work = string.format('function work()\n\tonly.log("I", "%s working ... ")\n', name)
	for _,v in ipairs(func or {}) do
		work = work .. string.format('\tWORK_FUNC_LIST["%s"]( "%s" )\n', v, name)
	end
	work = work .. 'end\n\n'

	-->> save file
	local data = head .. mark .. bind .. match .. work
	only.log("I", data)
	local TMP_FILE = OWN_APP_HOME_PATH .. mode .. "/" .. name .. '.tmp'
	local NEW_FILE = OWN_APP_HOME_PATH .. mode .. "/" .. name .. '.lua'
	local fd = io.open(TMP_FILE, "w+")
	fd:write( data )
	fd:close()
	os.execute(string.format("mv %s %s", TMP_FILE, NEW_FILE))
	OWN_STATUS_LIST_INFO[ OWN_MODE_INDEX[mode] ][ name ] =  "null"
	save_one_list( OWN_STATUS_LIST_INFO[ OWN_MODE_INDEX[mode] ], OWN_STATUS_LIST_NAME[ OWN_MODE_INDEX[mode] ], true )
end
function clean_old_app( mode, name )
	local TMP_FILE = OWN_APP_HOME_PATH .. mode .. "/" .. name .. '.tmp'
	local OLD_FILE = OWN_APP_HOME_PATH .. mode .. "/" .. name .. '.lua'
	os.execute(string.format("rm -rf %s %s", TMP_FILE, OLD_FILE))
end

function push_status( mode, key, val )
	OWN_STATUS_LIST_INFO[ mode ][ key ] = val
	save_one_list( OWN_STATUS_LIST_INFO[ mode ], OWN_STATUS_LIST_NAME[ mode ], true )
end

function pull_status( )
	return string.format('[{"name":"精准模式","value":%s},{"name":"部分模式","value":%s},{"name":"广播模式","value":%s},{"name":"点播模式","value":%s}]',
		cjson.encode(OWN_STATUS_LIST_INFO[ OWN_EXACT_MODE ]),
		cjson.encode(OWN_STATUS_LIST_INFO[ OWN_LOCAL_MODE ]), 
		cjson.encode(OWN_STATUS_LIST_INFO[ OWN_WHOLE_MODE ]),
		cjson.encode(OWN_STATUS_LIST_INFO[ OWN_ALONE_MODE ]))
end
--<[===============================CONFIG DATA===============================]>--
OWN_CONFIG_LIST_INFO = require('CONFIG_LIST').OWN_LIST

function push_config( name, cfgs )
	OWN_CONFIG_LIST_INFO[ name ] = cfgs
	save_one_list( OWN_CONFIG_LIST_INFO, "CONFIG_LIST", false )
end
function make_new_cfg( name, args, func )
	local cfgs = {work = {}, bool = {}, ways = {}}
	for i=1, #(func or {}) do
		cfgs["work"][ func[i] ] = WORK_FUNC_LIST["OWN_ARGS"][ func[i] ]
	end
	for k,v in pairs(args or {}) do
		if v[1] == "function" then
			cfgs["bool"][ v[2] ] = BOOL_FUNC_LIST["OWN_ARGS"][ v[2] ]
		end
	end
	cfgs["ways"] = freq["OWN_MUST"]
	push_config( name, cfgs )
end

function clean_old_cfg( name )
	push_config( name, nil )
end

function pull_config( name )
	--return cjson.encode( OWN_CONFIG_LIST_INFO[ name ] or {} )
	local info = cjson.encode( OWN_CONFIG_LIST_INFO[ name ] or {} )
	return string.gsub(info, '\\/', '/')
end
--<[===============================EXPLAIN DATA===============================]>--
OWN_EXPLAIN_LIST_INFO = require('EXPLAIN_LIST').OWN_LIST

function push_explain( name, info )
	OWN_EXPLAIN_LIST_INFO[ name ] = info
	save_one_list( OWN_EXPLAIN_LIST_INFO, "EXPLAIN_LIST", false )
end

function make_new_exp( name, args, func )
	local info = {work = {}, bool = {}}
	for i=1, #(func or {}) do
		info["work"][ i ] = func[i] 
	end
	for k,v in pairs(args or {}) do
		if v[1] == "function" then
			table.insert(info["bool"], v[2])
		end
	end
	push_explain( name, info )
end

function clean_old_exp( name )
	push_explain( name, nil )
end

function pull_explain( name )
	local info = {work = {}, bool = {}, ways = {}}
	if OWN_EXPLAIN_LIST_INFO[ name ] then
		for k,v in pairs(OWN_EXPLAIN_LIST_INFO[ name ]["bool"] or {}) do
			info["bool"][ v ] = BOOL_FUNC_LIST["OWN_HINT"][ v ]
		end
		for k,v in pairs(OWN_EXPLAIN_LIST_INFO[ name ]["work"] or {}) do
			info["work"][ v ] = WORK_FUNC_LIST["OWN_HINT"][ v ]
		end
	end
	info["ways"] = freq["OWN_JOIN"]
	return cjson.encode( info )
end
--<[===============================ALIAS DATA===============================]>--
OWN_ALIAS_LIST_INFO = require('ALIAS_LIST').OWN_LIST

function push_alias( name, info )
	OWN_ALIAS_LIST_INFO[ name ] = info
	save_one_list( OWN_ALIAS_LIST_INFO, "ALIAS_LIST", false )
end

function make_new_was( name, alias )
	push_alias( name, alias )
end

function clean_old_was( name )
	push_alias( name, nil )
end

function pull_alias( )
	return cjson.encode( OWN_ALIAS_LIST_INFO or {} )
end

--<[===============================SEARCH DATA===============================]>--
OWN_SEARCH_LIST_INFO = require('SEARCH_LIST').OWN_LIST

function push_search( temp, name )
	if OWN_SEARCH_LIST_INFO[ temp ] then
		table.insert(OWN_SEARCH_LIST_INFO[ temp ], name)
	else
		OWN_SEARCH_LIST_INFO[ temp ] = {name}
	end
	save_one_list( OWN_SEARCH_LIST_INFO, "SEARCH_LIST", false )
end

function make_new_idx( name, temp )
	if name and temp then
		push_search( temp, name )
	end
end

function clean_old_idx( mode, name )
	for temp in pairs(OWN_TEMPLET_LIST_INFO[ string.upper(mode) .. "_INFO" ] or {}) do
		utils.tab_remove_ivalue(OWN_SEARCH_LIST_INFO[ temp ], name)
	end
	save_one_list( OWN_SEARCH_LIST_INFO, "SEARCH_LIST", false )
end

function pull_search( temp, mode )
	if not OWN_TEMPLET_LIST_INFO[ string.upper(mode) .. "_NAME" ][ temp ] then return '{}' end
	local info = { status = {}, alias = {} }
	local apps = OWN_SEARCH_LIST_INFO[ temp ]
	for _,v in pairs(apps or {}) do
		info["status"][ v ] = OWN_STATUS_LIST_INFO[ OWN_MODE_INDEX[mode] ][ v ]
		info["alias"][ v ] = OWN_ALIAS_LIST_INFO[ v ]
	end
	return cjson.encode( info )
end
