# Changelog

All notable changes to the **MEMZone.WriteLog** module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-14

### Added

- `Initialize-WriteLog` - Module initialization with configurable log path, console output, debug logging, and size-based rotation.
- `Write-Log` - Structured logging with severity levels, dual console/file output, and rich formatting support.
- `Write-LogBuffer` - Buffered log flushing for improved I/O performance.
- `Test-LogFile` - Log directory/file creation and size-based rotation.
- `Format-Message` - Rich text formatting: Block, CenteredBlock, Line, InlineHeader, InlineSubHeader, Timeline, TimelineHeader, List, Table modes.
- `Write-FunctionHeaderOrFooter` - Debug-level function entry/exit tracing with parameter logging.
- `Invoke-WithAnimation` - Background runspace execution with animated console progress indicators (Spinner, Dots, Braille, Bounce, Box).
- `Invoke-WithStatus` - Synchronous execution with success/failure status indicators.
- Pester 5 unit tests.
- PSScriptAnalyzer validation.
- GitHub Actions CI/CD pipeline with automated PSGallery publishing.
- Build script supporting Analyze, Test, Build (compiled single-file), and Publish tasks.
