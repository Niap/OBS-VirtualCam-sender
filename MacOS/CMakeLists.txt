cmake_minimum_required(VERSION 3.5)
project(OBS-virtualcam-sender)


add_executable(OBS-virtualcam-sender
	./main.m
    ./Server.m
    ../video_generator.c)

target_link_libraries(OBS-virtualcam-sender "-framework Cocoa")
include_directories(
    ./)