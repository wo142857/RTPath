local cjson			= require('cjson')
local scene			= require('scene')
local redis_api			= require('redis_pool_api')
local luakv_api			= require('luakv_pool_api')
local lualog			= require('lualog')
local gosay			= require('gosay')
local pool			= require('pool')
local monitor			= require('monitor')
local route			= require('route')
local model			= require('model')
local utils			= require('utils')
local cutils			= require('cutils')
local only			= require('only')
local supex			= require("supex")
local cachekv			= require("cachekv")
local cutils			= require('cutils')

local init_data			= require("init_data")
local CFG_LIST			= require("cfg")
local scan 			= require("scan")
local FACTORY			= require('FACTORY_LIST')
local KV_INFO_LIST		= require('KV_INFO_LIST')

local CLASSIFY			= CFG_LIST["OWN_INFO"]["OPEN_LOGS_CLASSIFY"]

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

local OWN_MAIN_INIT = {
	[OWN_EXACT_MODE] = model.exact_init,
	[OWN_LOCAL_MODE] = model.local_init,
	[OWN_WHOLE_MODE] = model.whole_init,
	[OWN_ALONE_MODE] = model.alone_init,
}
local OWN_MAIN_CONTROL = {
	[OWN_EXACT_MODE] = model.exact_control,
	[OWN_LOCAL_MODE] = model.local_control,
	[OWN_WHOLE_MODE] = model.whole_control,
	[OWN_ALONE_MODE] = model.alone_control,
}
local OWN_MAIN_INSMOD = {
	[OWN_EXACT_MODE] = model.exact_insmod,
	[OWN_LOCAL_MODE] = model.local_insmod,
	[OWN_WHOLE_MODE] = model.whole_insmod,
	[OWN_ALONE_MODE] = model.alone_insmod,
}
local OWN_MAIN_RMMOD = {
	[OWN_EXACT_MODE] = model.exact_rmmod,
	[OWN_LOCAL_MODE] = model.local_rmmod,
	[OWN_WHOLE_MODE] = model.whole_rmmod,
	[OWN_ALONE_MODE] = model.alone_rmmod,
}
local OWN_MAIN_RUNMODS = {
	[OWN_EXACT_MODE] = model.exact_runmods,
	[OWN_LOCAL_MODE] = model.local_runmods,
	[OWN_WHOLE_MODE] = model.whole_runmods,
	[OWN_ALONE_MODE] = model.alone_runmods,
}


local OWN_FACTORY_LIST = {}

function app_line_init()
	--> init first
	lualog.setpath( CFG_LIST["OWN_INFO"]["DEFAULT_LOG_PATH"] )
	lualog.setlevel( CFG_LIST["OWN_INFO"]["LOGLV"] )

	lualog.open('monitor')
	lualog.open('manage')
	lualog.open('access')

	--> init redis pool
	redis_api.init()
	--> init luakv pool
	luakv_api.init()
	--> init monitor
	monitor.mon_init()
	--> init maps
	pool.init_map( )

	OWN_MAIN_INIT[ OWN_EXACT_MODE ]()
	OWN_MAIN_INIT[ OWN_LOCAL_MODE ]()
	OWN_MAIN_INIT[ OWN_WHOLE_MODE ]()
	OWN_MAIN_INIT[ OWN_ALONE_MODE ]()
	--> init model
	route.load_all_app( OWN_EXACT_MODE, OWN_MAIN_INSMOD[ OWN_EXACT_MODE ] )
	route.load_all_app( OWN_LOCAL_MODE, OWN_MAIN_INSMOD[ OWN_LOCAL_MODE ] )
	route.load_all_app( OWN_WHOLE_MODE, OWN_MAIN_INSMOD[ OWN_WHOLE_MODE ] )
	route.load_all_app( OWN_ALONE_MODE, OWN_MAIN_INSMOD[ OWN_ALONE_MODE ] )
	--> init factory
	for _, one_factory in ipairs(FACTORY["APP_LIST"]) do
		local fun_name = one_factory[1]
		local fun_cntl = one_factory[2]
		if fun_cntl == "open" then
			table.insert( OWN_FACTORY_LIST, require(fun_name).handle )
			print( string.format("FACTORY===%s===LOADING ... .. .", fun_name) )
		end
	end
	--> 初始化KV的超时值
	cachekv.init_expire_keys( CFG_LIST["EXP_KEYS"] or {} )
end

function app_scco_init( sch )
	supex["__TASKER_SCHEME__"] = sch

	app_line_init()
end

function app_type()
	supex["__WORK_TYPE__"] = true
end

function app_exit()
	--> free final
	lualog.close( )
end



function app_rfsh( top, sfd )
	supex["_FINAL_STAGE_"] = top
	only.log("S", 'rfsh logs ... .. .')
end

-- 名称:app_monitor
-- 功能:监控系统接口
-- 参数:
-- 返回值:
-- 修改:新生成函数 程少远　2015/05/12
function app_monitor( idx )
	lualog.open('monitor')
	monitor.mon_stat( idx )
	lualog.open('access')
end

function app_cntl( top, name, cmds, mode )
	supex["_FINAL_STAGE_"] = top
	only.log("I", string.format("【%s】 ------> |model:%s|name:%s", cmds, mode, name))
	local ctrl_cmd_list = {
		open = function( name, mode )
			if route.check_status( mode, name ) then
				OWN_MAIN_CONTROL[ mode ]( name, true )
				route.push_status( mode, name, "open" )
			end
		end,
		close = function( name, mode )
			if route.check_status( mode, name ) then
				OWN_MAIN_CONTROL[ mode ]( name, false )
				route.push_status( mode, name, "close" )
			end
		end,
		insmod = function( name, mode )
			OWN_MAIN_INSMOD[ mode ]( name, true )
			route.push_status( mode, name, "open" )
		end,
		rmmod = function( name, mode )
			OWN_MAIN_RMMOD[ mode ]( name )
			route.push_status( mode, name, "null" )
		end,
		delete = function( name, mode )
			OWN_MAIN_RMMOD[ mode ]( name )
			route.push_status( mode, name, nil )
			local mode_list = {
				[1] = "exact",
				[2] = "local",
				[3] = "whole",
				[4] = "alone",
			}
			route.clean_old_app( mode_list[ mode ], name )
			route.clean_old_cfg( name )
			route.clean_old_exp( name )
			route.clean_old_was( name )
			route.clean_old_idx( mode_list[ mode ], name )
		end,
	}
	ctrl_cmd_list[cmds]( name, mode )
end


function app_pull( top, sfd )
	supex["_FINAL_STAGE_"] = top
	supex["_SOCKET_HANDLE_"] = sfd
	--> come into manage model
	lualog.open( "manage" )
	only.log("D", '_________________________________START_________________________________________')
	--> get data
	local data = app_lua_get_body_data(sfd)
	only.log("I", string.gsub(data, "%%", "%%%%"))
	if data then
		local ok,jo = pcall(cjson.decode, data)
		if not ok then
			only.log('E', "error json body <--> " .. data)
			goto DO_NOTHING
		end
		--> parse data
		local pull_cmd_list = {
			get_all_app = function(  )
				local body = route.pull_status()
				gosay.resp( 200, body )
			end,
			get_all_was = function(  )
				local body = route.pull_alias()
				gosay.resp( 200, body )
			end,
			get_tmp_app = function(  )
				local body = route.pull_search( jo["tmpname"], jo["mode"] )
				gosay.resp( 200, body )
			end,
			get_all_tmp = function(  )
				local body = route.pull_templet( jo["mode"] )
				gosay.resp( 200, body )
			end,
			get_app_cfg = function( )
				local config = route.pull_config( jo["appname"] )
				local data = string.format('{"appname":"%s","config":%s}', jo["appname"], config)
				gosay.resp( 200, data )
			end,
			get_app_exp = function( )
				local explain = route.pull_explain( jo["appname"] )
				local data = string.format('{"appname":"%s","explain":%s}', jo["appname"], explain)
				gosay.resp( 200, data )
			end,
			get_tmp_arg = function( )
				local info = {}
				info[ "format" ] = KV_INFO_LIST["OWN_INFO"]["format"]
				info[ "args" ] = {}
				local keys = route.pull_templet( jo["mode"], jo["tmpname"] )
				for i=1, #(keys or {}) do
					table.insert( info[ "args" ], { [tostring( keys[i] )] = KV_INFO_LIST["OWN_INFO"]["keywords"][tostring( keys[i] )] } )
				end
				local data = cjson.encode(info)
				only.log("I", data)
				gosay.resp( 200, data )
			end,
			get_all_job = function( )
				local info = {}
				info[ "func" ] = KV_INFO_LIST["OWN_INFO"]["workfunc"][ jo["mode"] ] or {}
				local data = cjson.encode(info)
				only.log("I", data)
				gosay.resp( 200, data )
			end,
			get_all_arg = function( )
				local info = {}
				local keys = route.pull_templet()
				for k,_ in pairs(KV_INFO_LIST["OWN_INFO"]["keywords"] or {}) do
					table.insert( info, k )
				end
				local data = cjson.encode(info)
				only.log("I", data)
				gosay.resp( 200, data )
			end
		}
		if jo["operate"] then 
			local ok,result = pcall( pull_cmd_list[ jo["operate"] ] )
			if not ok then
				only.log("E", result)
			end
		end
	end
	::DO_NOTHING::
	only.log("D", '_________________________________OVER_________________________________________\n\n')
	--> reset to main
	lualog.open( "access" )
end

function app_push( top, sfd )
	supex["_FINAL_STAGE_"] = top
	supex["_SOCKET_HANDLE_"] = sfd
	--> come into manage model
	lualog.open( "manage" )
	only.log("D", '_________________________________START_________________________________________')
	--> get data
	local data = app_lua_get_body_data(sfd)
	only.log("S", string.gsub(data, "%%", "%%%%"))
	if data then
		local ok,jo = pcall(cjson.decode, data)
		if not ok then
			only.log('E', "error json body <--> " .. data)
			goto DO_NOTHING
		end
		--> parse data
		local push_cmd_list = {
			ctl_one_app = function( )
				app_cntl( top, jo["appname"], jo["status"], OWN_MODE_INDEX[jo["mode"]] )
			end,
			fix_app_cfg = function( )
				route.push_config( jo["appname"], jo["config"] )
			end,
			new_one_tmp = function( )
				route.push_templet( jo["mode"], jo["tmpname"], jo["remarks"], jo["args"] )
			end,
			new_one_app = function( )
				route.make_new_app( jo["mode"], jo["appname"], jo["args"], jo["func"])
				route.make_new_cfg( jo["appname"], jo["args"], jo["func"] )
				route.make_new_exp( jo["appname"], jo["args"], jo["func"] )
				route.make_new_was( jo["appname"], jo["nickname"] )
				route.make_new_idx( jo["appname"], jo["tmpname"] )
			end
		}
		if jo["operate"] then 
			local ok,result = pcall( push_cmd_list[ jo["operate"] ] )
			if not ok then
				only.log("E", result)
			end
		end
	end
	::DO_NOTHING::
	only.log("D", '_________________________________OVER_________________________________________\n\n')
	--> reset to main
	lualog.open( "access" )
end


--[[
--name:usr_testing_transmit
--func:transmit testing user's data to new version server
--input parm:@indata @path
--]]
local function usr_testing_transmit(indata, path)
		local app_srv = link["OWN_DIED"]["http"][path]
		--local data = utils.compose_http_json_request(app_srv, path, nil, indata)
		only.log("S",string.format("----------begin to send[%s]----------------",indata))
		for k,v in pairs(app_srv) do
			local ret = http_short_api.http(v, indata, false, nil)
			if ret <= 0 or ret == nil then
				only.log("S","--------------retransmission fail------------")
				return
			end
		end
		only.log("S","----------------retransmission success------------------")
end

--名 称:add_origin_key_value
--功 能:向数据源中添加数据
--参 数:key 数据的名称，value 数据的值
--返回值:
--说 明:
function add_origin_key_value(key, value)
	if  key then
		only.log("I", "[[OUR_BODY_TABLE add data key:" .. key  .." value is:" .. (scan.dump(value) or ' '))
		supex.get_our_body_table()[key] = value
	end
end


function main_call( )
	scene.init( )
	--添加源数据
	lualog.open( "factory" )
	for _, one_fun in ipairs( OWN_FACTORY_LIST ) do
		local ok, err = pcall(one_fun)
		if not ok then
			only.log('E', err)
		end
	end
	--- add @ here for first run before all modules
	lualog.open( "init_data" )
	local ok, err = pcall(init_data.handle, false)
	if not ok then
		only.log('E', string.format("pcall init_data.handle error:%s", err))
	end
	lualog.open( "access" )
	--> run call
	monitor.mon_come()
	local app_name = supex.get_our_uri_table()["app_name"]
	local app_mode = supex.get_our_uri_table()["app_mode"]
	local cmp_need = (not app_name) and (not app_mode or app_mode == "exact" or app_mode == "local")
	if cmp_need then
		--> parse map
		local our_body_table = supex.get_our_body_table()
		for k, v in pairs( our_body_table or {}) do
			pool.set_map( k , v )
		end
	end
	if app_mode then
		if not CLASSIFY then
			lualog.open( app_mode )
		end
		--only.log("I", string.format("app_mode->[%s] OWN_APP_MODE->[%s] OWN_MODE_INDEX->[%d]", app_mode, pool["OWN_APP_MODE"], OWN_MODE_INDEX[app_mode]))
		OWN_MAIN_RUNMODS[ OWN_MODE_INDEX[app_mode] ]( app_name, not app_name )
	else
		-->>[alone]
		if not CLASSIFY then
			lualog.open( "alone" )
		end
		OWN_MAIN_RUNMODS[ OWN_ALONE_MODE ]( app_name, not app_name )
		-->>[whole]
		if not CLASSIFY then
			lualog.open( "whole" )
		end
		OWN_MAIN_RUNMODS[ OWN_WHOLE_MODE ]( app_name, not app_name  )
		-->>[exact]
		if not CLASSIFY then
			lualog.open( "exact" )
		end
		OWN_MAIN_RUNMODS[ OWN_EXACT_MODE ]( app_name, not app_name )
		-->>[local]
		if not CLASSIFY then
			lualog.open( "local" )
		end
		OWN_MAIN_RUNMODS[ OWN_LOCAL_MODE ]( app_name, not app_name )
		print(scan.dump(OWN_MAIN_RUNMODS[OWN_LOCAL_MODE]))
	end
	if cmp_need then
		--> reset map
		pool.reset_map( )
	end
	local data = cjson.encode( scene.pack() )
	only.log("I", data)
	gosay.resp( 200, data )
end


function app_call_1( top, sfd )
	lualog.open( "access" )
	only.log("D", '_________________________________START_________________________________________')
	supex["_FINAL_STAGE_"] = top
	supex["_SOCKET_HANDLE_"] = sfd

	--> get data
	supex.http_req_init( )
	supex.set_our_info_data( app_lua_get_recv_buf(sfd) )
	supex.set_our_path( app_lua_get_path_data(sfd) )
	supex.set_our_head( app_lua_get_head_data(sfd) )
	supex.set_our_body_data( app_lua_get_body_data(sfd) )
	supex.set_our_body_table( )
	supex.set_our_uri_args( app_lua_get_uri_args(sfd) )
	supex.set_our_uri_table()

	local our_body_table = supex.get_our_body_table()
	lualog.addinfo( our_body_table["accountID"] )
	only.log("I", "BODY DATA is:%s", supex.get_our_body_data())
	only.log("I", "URI DATA is:%s", supex.get_our_uri_args())
	only.log("D", "%s", scan.dump(supex.get_our_uri_table()))
	--[[
		if customer oriented system:transmit user's data
		"system type" is seted in file named "cfg.lua",value "true" or "false"
	--]]
	if CFG_LIST["OWN_INFO"]["CUSTOM_ORIENTED_SYSTEM"] == true then
		if utils.is_in_table( our_body_table["accountID"], CFG_LIST["TEST_ACCOUNT"] ) then
			only.log("I", "----------------custom oriented system:user data[%s]------------", supex.get_our_info_data())
			only.log("I", "----------------------is a testing user-----------------------")
			local path = "publicentry"
			usr_testing_transmit(supex.get_our_info_data(), path)
			return
		end
		only.log("I","----------------------is not a testing user-----------------------")
	end
	main_call( )


	--> reset to main
	lualog.open( "access" )
	lualog.addinfo( nil )

	only.log("D", '_________________________________OVER_________________________________________\n\n')
end

function app_call_2( top, msg )
	lualog.open( "access" )
	only.log("D", '_________________________________START_________________________________________')
	supex["_FINAL_STAGE_"] = top
	supex["_SOCKET_HANDLE_"] = nil

	------- method , head , body , path , uri_arg
	local our_method, our_head, our_body_data, path, our_uri_args =  utils.split_http_data(msg)
	--> get data
	supex.http_req_init( )
	supex.set_our_info_data(msg)
	supex.set_our_path( path )
	supex.set_our_method(our_method)
	supex.set_our_head(our_head)
	supex.set_our_body_data(our_body_data)
	supex.set_our_body_table( )
	supex.set_our_uri_args(our_uri_args)
	supex.set_our_uri_table( )
	

	only.log("I", "BODY DATA is:%s", tostring(supex.get_our_body_data()))
	local our_body_table = supex.get_our_body_table()
	lualog.addinfo( our_body_table["accountID"] )

	--> run call
	only.log("I", 'access : ' .. path)

	--local come_msize = collectgarbage("count")
	if CFG_LIST["OWN_INFO"]["CUSTOM_ORIENTED_SYSTEM"] == true then
		if utils.is_in_table( our_body_table["accountID"], CFG_LIST["TEST_ACCOUNT"] ) then
			only.log("I", "----------------custom oriented system:user data[%s]------------", supex.get_our_info_data())
			only.log("I", "----------------------is a testing user-----------------------")
			local path = "publicentry"
			usr_testing_transmit(supex.get_our_info_data(), path)
			return
		end
		only.log("I","----------------------is not a testing user-----------------------")
	end
	main_call( )
	--[[
	local done_msize = collectgarbage("count")
	collectgarbage("collect")
	local over_msize = collectgarbage("count")
	print( string.format("APPLY CALL COME : memory size \t[%d]KB \t[%d]M", come_msize, come_msize/1024) )
	print( string.format("APPLY CALL DONE : memory size \t[%d]KB \t[%d]M", done_msize, done_msize/1024) )
	print( string.format("APPLY CALL OVER : memory size \t[%d]KB \t[%d]M", over_msize, over_msize/1024) )
	print()
	]]--
	--> reset to main
	lualog.open( "access" )
	lualog.addinfo( nil )

	only.log("D", '_________________________________OVER_________________________________________\n\n')
end
