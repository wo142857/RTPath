--> 修改记录：刘勇跃，2016.6.21，根据大坝数据新格式删除IMEI，IMSI，添加mirrtalkID

local scan	= require('scan')
local only	= require('only')
local supex	= require('supex')

local rtpath	= require('rtpath')

local DataPackageModule = require("data_package")
local DataPackage	= DataPackageModule.DataPackage

module("rtpath_comp", package.seeall)

function handle()
	if (not supex.get_our_body_table()["collect"]) then
		return
	end

	--> Get field from Body
        local req_body	= supex.get_our_body_table()
	local data_pack = DataPackage:new(req_body['mirrtalkID'], req_body['accountID'],req_body['tokenCode'])

	if not data_pack:init(req_body) then
		return 
	end
	
	rtpath.handle(data_pack)
end
