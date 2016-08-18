module("link")

OWN_POOL = {
    mysql = {
--[[	app_mirrtalk___config = {
		host = '192.168.1.17',
		port = 3306,
		database = 'config',
		user = 'observer',
		password ='abc123',
	},]]--
	--rtpath = {                                                                                                                                                                   
        --        host = '127.0.0.1',
	--        port = 3306,
	--        database = 'wqq',
	--        user = 'root',
	--        password ='123456',
        -- },
	--[[
	poi_road = {                                                                                                                                                                   
                host = '192.168.1.17',
	        port = 3306,
	        database = 'dataTest',
	        user = 'dataTest',
	        password ='DT456',
         }, 
	 ]]--
	--[[
	poi_road = {                                                                                                                                                                   
                host = '192.168.1.3',
	        port = 3306,
	        database = 'test',
	        user = 'app_roadmap',
	        password ='MTrmap369',
         }, 
	]]--
--[[	app_crowd___crowd = {
            host = '192.168.1.3',
            port = 3306,
            database = 'crowdRewards',
            user = 'app_crowd',
            password ='appcrabc123',
        },
	app_online___computation = {
		host = '192.168.11.142',
		port = 3306,
		database = 'onlineComputation',
		user = 'root',
		password ='xuan',
	},]]--
    },
    redis = {
     --   statistic = {
     --       host = "192.168.71.66",
     --       port = 6006,
     --  },
       
        rtpath1 = {
            host = "172.16.51.212",
            port = 5097,
        },
        rtpath2 = {
            host = "172.16.51.212",
            port = 5098,
        },
        rtpath3 = {
            host = "172.16.51.212",
            port = 5099,
        },
        rtpath4 = {
            host = "172.16.51.212",
            port = 6000,
        },
        roadName = {
            host = "172.16.71.95",
            port = 6002,
        },
	--[[
        private = {
            host = "192.168.1.11",
            port = 6379,
        },
	mapRoadInfo = {
        	host = '192.168.1.9',
                port = 5603,
       	},
	roadRelation = {
            host = '192.168.1.10',
            port =  4060,
        },
        mapRoadLine = {
            host = '192.168.1.10',
            port =  5602,
        },
        mapLineNode = {
            host = '192.168.1.10',
            port =  5601,
        },
        mapLandMark = {
                host = '192.168.1.10',
                port = 5531
        },
	mapGridOnePercent = {
                host = '192.168.1.10',
                port = 5071,
        },
	mileageInfo = {
		host = '192.168.11.142',
		port = 6379,
	},]]--
    },
}


OWN_DIED = {
    mysql = {
    },
    redis = {
    },
    http = {
    },
}



