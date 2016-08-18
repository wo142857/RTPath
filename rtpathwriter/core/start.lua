local BASE_PATH = "open"
package.path = string.format('%s/?.lua;%s/apply/?.lua;%s/public/?.lua;%s/linkup/?.lua;%s/lib/?.lua;./?.lua;%s', BASE_PATH, BASE_PATH, BASE_PATH, BASE_PATH, BASE_PATH, package.path)
package.cpath = string.format('%s/?.so;%s/lib/?.so;%s', BASE_PATH, BASE_PATH, package.cpath)

local RUN_MOLD = os.getenv ("RUN_MOLD") -- get string ENV
local SRC_FILE = os.getenv ("SRC_FILE") -- get string ENV
local HOOK_FILE = os.getenv ("HOOK_FILE") -- get string ENV
local CLIENT_ARGS = os.getenv ("CLIENT_ARGS") -- get string ENV
local CLIENT_NAME = os.getenv ("CLIENT_NAME") -- get string ENV

package.path = string.format('code/%s/?.lua;code/%s/deploy/?.lua;%s', CLIENT_NAME, CLIENT_NAME, package.path)

local utils = require('utils')
local only = require('only')
local APP_REDIS_API     = require('redis_pool_api')
local APP_MYSQL_API     = require('mysql_pool_api')

local ffi = require('ffi')
ffi.cdef[[ int getpid(void); ]]

local pid = ffi.C.getpid()
--local c = ffi.load("c")
--local pid = c.getpid()
local pidlog = CLIENT_NAME .. " pid : " .. pid .. "\n"
--> load main function
only.log('D', SRC_FILE)
local fd = io.open(SRC_FILE, 'r+')
if fd then
	local lua_run_cmds = fd:read('*a')
	MAINFUNC = utils.load_lua_string(lua_run_cmds)
end
--> load hook function
only.log('D', HOOK_FILE)
fd = io.open(HOOK_FILE, 'r+')
if fd then
	local lua_hook_cmds = fd:read('*a')
	HOOKFUNC = utils.load_lua_string(lua_hook_cmds)
end



---> do main API
local function anytime(...)
	local ok,info = utils.run_lua_function(MAINFUNC, ...)
	if not ok then
		only.log('E', info)
	end
end
local function always(...)
	os.execute(string.format('echo -ne "\\a\x1B[31;1m%s\x1B[m"', pidlog))
	-->> add fiter
	if HOOKFUNC then
		-->> below is equal --> HOOKFUNC()
		local ok,info = utils.run_lua_function(HOOKFUNC, ...)
		if not ok then
			only.log('E', info)
		end
	end
	-->> do main
	local socket = require('socket')
	local cfg = require('cfg')
	repeat
		anytime(...)
		socket.sleep(cfg["DELAY"])
	until false
end
local TB_FUNC = {
	anytime = anytime,
	always = always,
}

local function save_pid_list(info)
	local f = "./PID_LIST"
	local fd = assert(io.open(f, "a"))
	fd:write(info)
	fd:close()
end
local function main()
	APP_REDIS_API.init( )
        APP_MYSQL_API.init( )
	save_pid_list(pidlog)
	TB_FUNC[RUN_MOLD](CLIENT_ARGS)
end

main()
