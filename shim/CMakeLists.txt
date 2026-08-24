cmake_minimum_required(VERSION 3.16)
project(zlibmojo C)

find_package(ZLIB REQUIRED)

add_library(zlibmojo SHARED zlib_wrapper.c)
target_link_libraries(zlibmojo PRIVATE ZLIB::ZLIB)
# _find_lib() in the Mojo package loads lib/libzlibmojo.so on every platform.
set_target_properties(zlibmojo PROPERTIES SUFFIX ".so" PREFIX "lib")

install(TARGETS zlibmojo LIBRARY DESTINATION lib)
