# Regular use
CFLAGS=

ifneq ($(OS),Windows_NT)
	OS = $(shell uname)
 	ifeq "$(OS)" "Darwin"
		CFLAGS=-sectcreate __TEXT __info_plist Info.plist
	endif
endif
all:
	g++ $(CFLAGS) -I. hello.cpp -o hello
#to test if plist section is appended:
# otool -l ./hello | grep info_plist -B1 -A10
