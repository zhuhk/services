RootDir=.
include share/Makefile

all: output_init
	./build.sh

clean: clean_init
	./build.sh clean
