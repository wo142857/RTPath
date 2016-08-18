local http_api 		= require("http_short_api")
local APP_CONFIG_LIST 	= require('CONFIG_LIST')
local only 		= require('only')
local link 		= require("link")
local utils 		= require("utils")
local supex 		= require("supex")
local scene 		= require("scene")
local cjson		= require('cjson')

module("WORK_FUNC_LIST", package.seeall)


-->> private
OWN_HINT = {
	-->> exact local whole
	app_task_forward = {},
}

OWN_ARGS = {
	-->> exact local whole
	app_task_forward = {
		app_uri = "p2p_xxxxxxxxxxx",
	},

}

function make_scene_data( app_name )
	local info = utils.deepcopy(supex.get_our_body_table())
	info["private_data"] = scene.view( app_name )
	local data = cjson.encode( info )
	return data
end

function app_task_forward( app_name )
	local app_uri = APP_CONFIG_LIST["OWN_LIST"][app_name]["work"]["app_task_forward"]["app_uri"]
	local path = string.gsub(app_uri, "?.*", "")
	local app_srv = link["OWN_DIED"]["http"][ path ]
	local scene = make_scene_data( app_name )
	local data = utils.compose_http_json_request(app_srv, app_uri, nil, scene)
	local ok = http_api.http(app_srv, data, false)
	if not ok then
		only.log("E", "app_task_forward false")
	end
end
