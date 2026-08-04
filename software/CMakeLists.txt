cmake_minimum_required(VERSION 3.20)
project(count-mem-ops LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

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

# opt reads IR, not C, so clang lowers test.c first. The .ll lives in build/
# and is only regenerated when test.c changes.
add_custom_command(
  OUTPUT ${TEST_SOURCE}.ll
  COMMAND ${LLVM_TOOLS_BINARY_DIR}/clang -O0 -S -emit-llvm
          ${CMAKE_CURRENT_SOURCE_DIR}/${TEST_SOURCE}.c -o ${TEST_SOURCE}.ll
  MAIN_DEPENDENCY ${CMAKE_CURRENT_SOURCE_DIR}/${TEST_SOURCE}.c
  COMMENT "Generating ${TEST_SOURCE}.ll from ${TEST_SOURCE}.c"
  VERBATIM
)

# Load the plugin into opt and run the pass over the generated IR.
add_custom_target(run
  COMMAND ${LLVM_TOOLS_BINARY_DIR}/opt
          -load-pass-plugin=$<TARGET_FILE:CountMemOps>
          -passes=count-mem-ops -disable-output ${TEST_SOURCE}.ll
  DEPENDS CountMemOps ${TEST_SOURCE}.ll
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  COMMENT "Running count-mem-ops on ${TEST_SOURCE}.ll"
  VERBATIM
)

# `check` fails loudly if the counts ever drift from expected.txt.
add_custom_target(check
  COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/check.sh
          ${LLVM_TOOLS_BINARY_DIR}/opt $<TARGET_FILE:CountMemOps>
          ${TEST_SOURCE}.ll ${CMAKE_CURRENT_SOURCE_DIR}/expected.txt
  DEPENDS CountMemOps ${TEST_SOURCE}.ll
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  COMMENT "Checking count-mem-ops output against expected.txt"
  VERBATIM
)

# The built-in `clean` already removes build artifacts but keeps the cache;
# `distclean` wipes build/ entirely. Reconfigure with `cmake -B build` after.
add_custom_target(distclean
  COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_BINARY_DIR}
  COMMENT "Removing ${CMAKE_BINARY_DIR}"
  VERBATIM
)