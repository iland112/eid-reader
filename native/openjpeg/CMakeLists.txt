cmake_minimum_required(VERSION 3.18)
project(openjpeg_flutter C)

# OpenJPEG source directory
set(OPJ_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/openjpeg/src/lib/openjp2")

# Generate config headers
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/opj_config.h.in"
  "${CMAKE_CURRENT_BINARY_DIR}/opj_config.h"
)
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/opj_config_private.h.in"
  "${CMAKE_CURRENT_BINARY_DIR}/opj_config_private.h"
)

# OpenJPEG library sources (matches upstream, no JPIP/bench/test/lut-gen)
# Plus our Flutter wrapper (opj_flutter.c)
set(OPJ_SOURCES
  ${OPJ_SRC_DIR}/thread.c
  ${OPJ_SRC_DIR}/bio.c
  ${OPJ_SRC_DIR}/cio.c
  ${OPJ_SRC_DIR}/dwt.c
  ${OPJ_SRC_DIR}/event.c
  ${OPJ_SRC_DIR}/function_list.c
  ${OPJ_SRC_DIR}/ht_dec.c
  ${OPJ_SRC_DIR}/image.c
  ${OPJ_SRC_DIR}/invert.c
  ${OPJ_SRC_DIR}/j2k.c
  ${OPJ_SRC_DIR}/jp2.c
  ${OPJ_SRC_DIR}/mct.c
  ${OPJ_SRC_DIR}/mqc.c
  ${OPJ_SRC_DIR}/openjpeg.c
  ${OPJ_SRC_DIR}/opj_clock.c
  ${OPJ_SRC_DIR}/opj_malloc.c
  ${OPJ_SRC_DIR}/pi.c
  ${OPJ_SRC_DIR}/sparse_array.c
  ${OPJ_SRC_DIR}/t1.c
  ${OPJ_SRC_DIR}/t2.c
  ${OPJ_SRC_DIR}/tcd.c
  ${OPJ_SRC_DIR}/tgt.c
  ${CMAKE_CURRENT_SOURCE_DIR}/opj_flutter.c
)

add_library(openjp2 SHARED ${OPJ_SOURCES})

target_include_directories(openjp2
  PRIVATE
    ${OPJ_SRC_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Thread support (pthreads on Android/Linux)
find_package(Threads QUIET)
if(Threads_FOUND AND CMAKE_USE_PTHREADS_INIT)
  target_compile_definitions(openjp2 PRIVATE MUTEX_pthread)
  target_link_libraries(openjp2 PRIVATE ${CMAKE_THREAD_LIBS_INIT})
else()
  target_compile_definitions(openjp2 PRIVATE MUTEX_stub)
endif()

# Link math library on Unix
if(UNIX)
  target_link_libraries(openjp2 PRIVATE m)
endif()

set_target_properties(openjp2 PROPERTIES
  C_STANDARD 99
  POSITION_INDEPENDENT_CODE ON
)
