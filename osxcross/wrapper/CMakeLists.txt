cmake_minimum_required(VERSION 3.20)
project(wrapper)

set(CMAKE_CXX_STANDARD 17)

add_executable(wrapper
	main.cpp
	target.cpp
	target.h
	compat.h
	progs.h
	tools.cpp
	tools.h)
