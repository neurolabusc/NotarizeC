cmake_minimum_required(VERSION 2.8.9)
project (hello)
add_executable(hello hello.cpp)
if(APPLE)
    message("--   Adding Apple plist")
    set_target_properties(hello PROPERTIES LINK_FLAGS "-Wl,-sectcreate,__TEXT,__info_plist,${CMAKE_SOURCE_DIR}/Info.plist")
endif()
# >mkdir build; cd build; cmake ..
# >make
# >launchctl plist hello
