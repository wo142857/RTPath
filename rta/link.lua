
module("link")

OWN_POOL = {
	redis = {
		public = {
			host = 'public.redis.daoke.com',
			port = 6349,
		},
		owner = {
			host = '127.0.0.1',
			port = 6400,
		},
		match_road = {
			host = '172.16.31.187',
			port = 5555,
		},
		
		rtpath = {
			hash='consistent',		
			{'mirrtalkID','rtpath1', '172.16.81.', 5097, 30},
                        {'mirrtalkID','rtpath2', '172.16.81.', 5098, 30},
                        {'mirrtalkID','rtpath3', '172.16.81.', 5099, 30},
                        {'mirrtalkID','rtpath4', '172.16.81.', 6000, 30},
		},

	},
	tcp = {
		tcp1 ={
			host = "127.0.0.1",
			port = 4140,
		}

	},

}

OWN_DIED = {
	http = {

		----测试服务器URI(转发多台)
		['publicentry'] = { 
		},

	},
}
