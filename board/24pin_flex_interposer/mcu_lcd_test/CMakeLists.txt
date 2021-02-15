cmake_minimum_required(VERSION 3.12)
include(pico_sdk_import.cmake)

project(riscboy_24pin_lcd_test C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
pico_sdk_init()

add_compile_options(-Wall)

add_executable(lcd_test
	main.c
)

target_link_libraries(lcd_test
	pico_stdlib
	hardware_interp
)

pico_add_extra_outputs(lcd_test)
