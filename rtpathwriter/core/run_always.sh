#!/bin/bash
export RUN_MOLD="always"

export COLOR_DEFAULT="\\033[0m"
export COLOR_BLACK="\\033[30;1m"
export COLOR_RED="\\033[31;1m"
export COLOR_GREEN="\\033[32;1m"
export COLOR_YELLOW="\\033[33;1m"
export COLOR_BLUE="\\033[34;1m"
export COLOR_PURPLE="\\033[35;1m"
export COLOR_SKYBLUE="\\033[36;1m"
export COLOR_GRAY="\\033[37;1m"

./core/client.sh $* &
echo -e $COLOR_YELLOW"<[==="$*"===]>"$COLOR_DEFAULT
