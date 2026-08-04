cmake_minimum_required(VERSION 3.20)
project(count-mem-ops LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(LLVM REQUIRED CONFIG)
message(STATUS "Using LLVM ${LLVM_PACKAGE_VERSION}")
separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND "${LLVM_DEFINITIONS}")

set(TEST_SOURCE test CACHE STRING "Base name of the C source to run the pass on")

add_library(CountMemOps MODULE CountMemOps.cpp)
target_include_directories(CountMemOps SYSTEM PRIVATE ${LLVM_INCLUDE_DIRS})
target_compile_definitions(CountMemOps PRIVATE ${LLVM_DEFINITIONS_LIST})
if(NOT LLVM_ENABLE_RTTI)
  target_compile_options(CountMemOps PRIVATE -fno-rtti)
endif()
if(APPLE)
  target_link_options(CountMemOps PRIVATE -undefined dynamic_lookup)
endif()

add_custom_target(run
  COMMAND ${LLVM_TOOLS_BINARY_DIR}/clang -O0 -S -emit-llvm
          ${CMAKE_CURRENT_SOURCE_DIR}/${TEST_SOURCE}.c -o ${TEST_SOURCE}.ll
  COMMAND ${LLVM_TOOLS_BINARY_DIR}/opt
          -load-pass-plugin=$<TARGET_FILE:CountMemOps>
          -passes=count-mem-ops -disable-output ${TEST_SOURCE}.ll
  BYPRODUCTS ${TEST_SOURCE}.ll
  DEPENDS CountMemOps
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  COMMENT "Running count-mem-ops on ${TEST_SOURCE}.c"
  VERBATIM
)