#!/bin/bash

# App Store Build Script for RealVision
echo "Building RealVision for App Store submission"

# Clean previous builds
echo "Cleaning previous builds"
flutter clean

# Get dependencies
echo "Getting dependencies"
flutter pub get

# Build for release with optimizations
echo "Building iOS release with optimizations"
flutter build ios --release --obfuscate --split-debug-info=debug-info/

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Build completed successfully!"
else
    echo "Build failed."
    exit 1
fi