#!/bin/bash

# Demark Example Xcode Project Generator
# This script creates an Xcode project for the Demark example app

set -e

echo "🔨 Creating Xcode project for Demark Example..."
echo

# Change to the Example directory
cd "$(dirname "$0")"

# Create Xcode project by opening Package.swift directly
echo "📦 Opening Package.swift in Xcode will create the project automatically"
echo

# Open in Xcode
if [ "$1" = "--open" ]; then
    echo "📱 Opening Package.swift in Xcode..."
    open Package.swift
fi

echo
echo "✅ Ready to work with Demark Example!"
echo "   Package: $(pwd)/Package.swift"
echo
echo "To open in Xcode:  open Package.swift"
echo "To build from CLI: swift build"
echo "To run from CLI:   swift run DemarkExample"
echo "To test from CLI:  swift test"