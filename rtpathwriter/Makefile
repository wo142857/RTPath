
EXE_LIST=daokespeed

help:
	-@./help.sh

libs:
	$(MAKE) -C ./open/lib clean
	$(MAKE) -C ./open/lib/

run:
	#sh client.sh $(EXE_LIST) &
	./core/run_always.sh $(EXE_LIST)

acb_daily:
	./core/run_anytime.sh $@

rtpathwriter:
	./core/run_anytime.sh $@



clean:
	$(MAKE) -C ./open/lib clean

push:
	git push origin HEAD:refs/for/master
