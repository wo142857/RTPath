module("BOOL_FUNC_LIST", package.seeall)

--不能有空格
OWN_HINT = {
	-->> continuous driving 
	is_continuous_driving_mileage_point = {
	},
	drive_online_point                  = {
	},
}

OWN_ARGS = {
	-->> continueous driving
	is_continuous_driving_mileage_point = {
		increase = 10,
	},
	drive_online_point                  = {
		increase = 10,
	},
}

OWN_LIST = {
	-->> direction
	is_continuous_driving_mileage_point = function( app_name, key )
		return string.format('judge.is_continuous_driving_mileage_point("%s")', app_name)
	end,
	drive_online_point                  = function( app_name, key )
		return string.format('judge.drive_online_point("%s")', app_name)
	end,
}
