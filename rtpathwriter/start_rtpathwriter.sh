#!/bin/sh
export PATH=/usr/local/bin/:$PATH
	cd /data/rtpathwriter
	make rtpathwriter

#27 10 * * * /data/acb_daily/crontab/start_acb_daily.sh
#30 0-23 * * * /data/acb_daily/crontab/start_acb_daily.sh
