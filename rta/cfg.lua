module("cfg")

keywords = {
	powerOn		= {{true},{},{},{}},
	powerOff	= {{true},{},{},{}},
	collect		= {{true},{},{},{}},

	accountID	= {{},{},{},{}},
	mirrtalkID	= {{},{},{},{}},
	tokenCode	= {{},{},{},{}},

	GSENSORTime	= {{},{},{},{}},
	gx		= {{},{},{},{}},
	gy		= {{},{},{},{}},
	gz		= {{},{},{},{}},

	GPSTime		= {{},{},{},{"drive_online_point"}},
	speed		= {{},{},{},{}},
	altitude	= {{},{},{},{}},
	direction	= {{},{},{},{"is_continuous_driving_mileage_point"}},
	position	= {{},{},{},{}},

	T_LONGDRI_MILEAGE	= {{},{},{},{}},
	T_ONLINE_HOUR 	= {{},{},{},{}},
}

workfunc = {
	["exact"] = {"app_task_forward"},
	["local"] = {"app_task_forward"},
	["whole"] = {"app_task_forward"},
	["alone"] = {},
}

ranklist = {-->other default is 0,the higher rank function will be run the first.
["is_continuous_driving_mileage_point"]		= 71,
["drive_online_point"]		= 72,
}

slotlist = {
	powerOn		= 1,
	powerOff	= 2,
	collect		= 3,

	accountID	= 20,
	IMEI		= 21,
	model		= 22,
	tokenCode	= 23,

	GSENSORTime	= 31,
	gx		= 32,
	gy		= 33,
	gz		= 34,

	GPSTime		= 35,
	speed		= 36,
	altitude	= 37,
	direction	= 38,
	longitude	= 39,
	latitude	= 40,
	extragps 	= 50,
	
	T_LONGDRI_MILEAGE = 63,
	T_ONLINE_HOUR = 64,
}

EXP_KEYS = {
}

--定义补充模块中文名称
MOD_NAME = {
}

OWN_INFO = {
	LOGLV = 5,
	SYSLOGLV = false,
	DEFAULT_LOG_PATH = "./logs/",
	--OPEN_LOGS_CLASSIFY = false,
	OPEN_LOGS_CLASSIFY = true,

	--if current system is for real customer set "true" or "false"
	CUSTOM_ORIENTED_SYSTEM = true,

	key_len = 20,
	bit_step = 5, --> must <= 6
	--> 20 * 5 kinds
}

-- testing users accounts
TEST_ACCOUNT = {
}
