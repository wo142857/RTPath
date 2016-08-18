#!/bin/bash
export CLIENT_NAME=$1
export CLIENT_ARGS=$2

LOG_PATH=./logs/
export LOG_FILE=$LOG_PATH$CLIENT_NAME
SRC_PATH=./code/$1/
export SRC_FILE=$SRC_PATH$CLIENT_NAME'.lua'
export HOOK_FILE=$SRC_PATH$CLIENT_NAME'-hook.lua'


#rm $LOG_FILE*.log
#> $LOG_FILE"_"$(date +%Y%m).log

if [ -f $SRC_FILE ];then
		echo -e $COLOR_YELLOW"<<==================>>     "$COLOR_SKYBLUE$CLIENT_NAME" START!     "$COLOR_YELLOW"<<==================>>"$COLOR_DEFAULT
		#luajit $SRC_FILE >> $LOG_FILE 2>&1	#cant not put log into file,because break by sleep.
		eval luajit ./core/start.lua APP_NAME=$CLIENT_NAME
fi
