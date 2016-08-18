#!/bin/bash

DELAY=0

function do_main_always(){
	##===========================<main function>=================================##
	echo -e "\n"$COLOR_RED"Start Run!"$COLOR_DEFAULT

	START_TIME=`date +%s`
	for ((i=1;i <= $#;i++));
	do
	{	eval local NAME=\$$i
		echo -e $COLOR_PURPLE"run "$COLOR_BLUE$NAME$COLOR_PURPLE" clients!"$COLOR_DEFAULT
		#local pro_name=($0 $*) && sleep $DELAY;sh "start.sh" ${pro_name[$i]}
		sleep $DELAY;eval ./core/start.sh \$$i
	}&
	done
	#wait
	END_TIME=`date +%s`
	echo -e $COLOR_SKYBLUE`expr $START_TIME + $DELAY`"------------>"$END_TIME$COLOR_DEFAULT
	echo -e $COLOR_RED"All Over!"$COLOR_DEFAULT
	##===========================<end>=================================##
}

function do_main_anytime(){
	##===========================<main function>=================================##
	echo -e "\n"$COLOR_RED"Start Run!"$COLOR_DEFAULT
	START_TIME=`date +%s`
	{
		echo -e $COLOR_PURPLE"run "$COLOR_BLUE$1$COLOR_PURPLE" clients!"$COLOR_DEFAULT
		#local pro_name=($0 $*) && sleep $DELAY;sh "start.sh" ${pro_name[$i]}
		sleep $DELAY;eval ./core/start.sh $*
	}&
	#wait
	END_TIME=`date +%s`
	echo -e $COLOR_SKYBLUE`expr $START_TIME + $DELAY`"------------>"$END_TIME$COLOR_DEFAULT
	echo -e $COLOR_RED"All Over!"$COLOR_DEFAULT
	##===========================<end>=================================##
}

if [ $# -eq 0 ];then
	echo -e "\n"$COLOR_RED"USE like: ./client.sh [\"PROJECT NAME\"]"$COLOR_DEFAULT
else
	case $RUN_MOLD in
		"always")
			do_main_always $*;;
		"anytime")
			do_main_anytime $*;;
		*)
			echo -e "\n"$COLOR_RED"UNUSE"$COLOR_DEFAULT;;
	esac
fi
