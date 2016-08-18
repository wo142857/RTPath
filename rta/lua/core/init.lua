local serv_name = app_lua_get_serv_name()

local path_list = {
	"lua/core/?.lua;",
	"lua/code/?.lua;",
	string.format("lua/%s/code/?.lua;", 	  serv_name),
	string.format("lua/%s/process/?.lua;",	  serv_name),
	string.format("lua/%s/with/exact/?.lua;", serv_name),
	string.format("lua/%s/with/local/?.lua;", serv_name),
	string.format("lua/%s/with/whole/?.lua;", serv_name),
	string.format("lua/%s/with/alone/?.lua;", serv_name),

	string.format("lua/%s/data/exact/?.lua;", serv_name),
	string.format("lua/%s/data/local/?.lua;", serv_name),
	string.format("lua/%s/data/whole/?.lua;", serv_name),
	string.format("lua/%s/data/alone/?.lua;", serv_name),
	
	string.format("lua/%s/data/depot/?.lua;", serv_name),

	string.format("lua/%s/deploy/?.lua;", serv_name),

	"../../open/lib/?.lua;",
	"../../open/apply/?.lua;",
	"../../open/spxonly/?.lua;",
	"../../open/linkup/?.lua;",
	"../../open/public/?.lua;",

	"open/?.lua;",
}

package.path = table.concat(path_list) .. package.path
package.cpath = "../../open/lib/?.so;" .. "open/?.so;" .. package.cpath
