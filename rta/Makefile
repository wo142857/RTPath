
all:
	echo "make run"
run:
	@-if [ ! -d ./logs ];then mkdir logs; fi
	nohup ./rta &
load:
	@-if [ ! -d ./logs ];then mkdir logs; fi
	@sh init/init.sh rta
	./rta &
	sleep 3
	luajit init/rta_load.lua
	killall rta

