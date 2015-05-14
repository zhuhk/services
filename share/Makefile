_init:all

ifndef RootDir
  RootDir=".."
endif
output_init:
	rm -rf output
	mkdir -p output
	if [ -d shell ];then cp -rf shell output/; fi
	if [ -d conf ];then cp -rf conf output/; fi
	if [ -d tools ];then cp -rf tools output/; fi
	if [ -d "$(RootDir)/share/tools" ]; then cp -rf $(RootDir)/share/tools output; fi
	find output -name .git  |xargs rm -rf
	find output -name ".py?"  |xargs rm -f

clean_init :
	rm -rf output
	find . -name ".py?"  |xargs rm -f
	find . -name ".o"  |xargs rm -f

