cmake_minimum_required(VERSION 3.5)
project(OBS-virtualcam-sender)


add_executable(OBS-virtualcam-sender
	./main.cpp
    ./queue/share_queue_write.cpp
    ../video_generator.c)
	
include_directories(
    ./)