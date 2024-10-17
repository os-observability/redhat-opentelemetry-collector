# OpenTelemetry Collector Component Parser

This program parses and displays information about OpenTelemetry Collector components based on their metadata files. It provides a summary of the support levels for various components across different signal types (traces, metrics, and logs).

## Features

- Clones or updates OpenTelemetry Collector repositories
- Parses component metadata files
- Displays support levels for receivers, processors, exporters, connectors, and extensions

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/otel-component-parser.git
   cd otel-component-parser
   ```

2. Build the program:
   ```
   go build -o component-parser
   ```

## Usage

Run the program with:
```
./component-parser
```

The program will clone or update the OpenTelemetry Collector and OpenTelemetry Collector Contrib repositories, parse the metadata files, and display the support levels for each component.
