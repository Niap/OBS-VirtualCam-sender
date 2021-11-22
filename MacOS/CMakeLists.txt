cmake_minimum_required(VERSION 3.5)
project(OBS-virtualcam-sender)

find_library(PEERTALK_LIB Peertalk "${CMAKE_CURRENT_SOURCE_DIR}/libs/")

set(CMAKE_INSTALL_RPATH "@executable_path") 

message("Found PEERTALK_LIB framework: ${PEERTALK_LIB}")

add_executable(OBS-virtualcam-sender
	./main.m
    ./Server.m)


target_link_libraries(OBS-virtualcam-sender "${CMAKE_CURRENT_SOURCE_DIR}/libs/libyuv.a" "-framework Cocoa" "${PEERTALK_LIB}")
include_directories(
    ./ ./includes "${PEERTALK_LIB}/Headers/")