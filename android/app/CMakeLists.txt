cmake_minimum_required(VERSION 3.18)
project("llama_bridge" C CXX)

# Only arm64-v8a is supported
if(NOT ANDROID_ABI STREQUAL "arm64-v8a")
    message(STATUS "Skipping native build for ${ANDROID_ABI} - only arm64-v8a is supported")
    return()
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

get_filename_component(LLAMA_SRC_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/src/main/jni/llama.cpp"
    ABSOLUTE
)

if(NOT EXISTS "${LLAMA_SRC_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_SRC_DIR}")
endif()

message(STATUS "Using llama.cpp at: ${LLAMA_SRC_DIR}")

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_CPU_ALL_VARIANTS OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL OFF CACHE BOOL "" FORCE)

add_subdirectory(${LLAMA_SRC_DIR} ${CMAKE_BINARY_DIR}/llama.cpp)

add_library(llama_bridge SHARED src/main/jni/llama_bridge.cpp)

target_include_directories(llama_bridge PRIVATE
    ${LLAMA_SRC_DIR}
    ${LLAMA_SRC_DIR}/include
    ${CMAKE_BINARY_DIR}/llama.cpp/include
)

target_link_libraries(llama_bridge PRIVATE
    llama
    log
    android
)

target_compile_options(llama_bridge PRIVATE -Wall -Wno-unused-parameter -Wno-sign-compare)
