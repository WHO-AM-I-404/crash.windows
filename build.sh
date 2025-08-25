#!/bin/bash

# Build script for Windows executable on Linux
echo "Building Windows executable..."

# Compile with NASM
nasm -f win64 crash.asm -o crash.obj

# Link with MinGW cross-compiler
x86_64-w64-mingw32-gcc -o crash.exe crash.obj \
  -lkernel32 -luser32 -ladvapi32 -lole32

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Build successful: crash.exe"
    file crash.exe
else
    echo "Build failed!"
    exit 1
fi
