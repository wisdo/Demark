# Demark Example App

A comprehensive example application demonstrating the capabilities of the **Demark** HTML-to-Markdown conversion library.

## Features

- 🖥️ **Dual-Pane Interface**: HTML input on the left, Markdown output on the right  
- 📝 **Source & Rendered Views**: Toggle between raw Markdown and rendered output
- 🎯 **Sample Documents**: Pre-built HTML examples (Simple, Blog, Documentation, Complex)
- ⚙️ **Live Configuration**: Real-time conversion options adjustment
- 🚀 **Swift 6 Ready**: Built with strict concurrency and modern Swift features

## Running the Example

### Quick Start

```bash
# Use the convenience script from project root
./run-example.sh

# Or run manually
cd Example
swift run DemarkExample
```

### Development in Xcode

```bash
# Generate and open Xcode project  
./generate-xcodeproj.sh --open

# Or open Package.swift directly
open Package.swift
```

## Requirements

- **Swift 6.0+**
- **macOS 14.0+** or **iOS 17.0+**  
- **Xcode 15.0+** (for development)

## License

This example is part of the Demark package and is available under the MIT license.