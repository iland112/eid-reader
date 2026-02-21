cmake_minimum_required(VERSION 3.18)
project(eid_reader_native C)

# Build OpenJPEG from source
add_subdirectory(
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../../native/openjpeg"
  "${CMAKE_CURRENT_BINARY_DIR}/openjpeg"
)
