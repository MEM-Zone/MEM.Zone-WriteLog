# Changelog

All notable changes to the **MEMZone.WriteLog** module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-07-29

### Changed

- `Invoke-WithAnimation` execution model reversed: the scriptblock now runs on the **calling thread** in the caller's session state, and only the spinner runs in a background runspace. Previously the scriptblock ran in a background runspace while bound to the caller's session state — two threads sharing one scope stack, which can corrupt variable lookups. Session-bound operations (`Import-Module`, `New-PSDrive`, `Set-Location`) now work inside the scriptblock.
- `-Variables` is now injected via `InvokeWithContext` into the scriptblock's own session state. Previously the values were set on the animation runspace, which a session-bound scriptblock never resolved.
- `Invoke-WithAnimation` and `Invoke-WithStatus` now rethrow the original `ErrorRecord` (exception type and stack preserved) instead of throwing the error message as a string.
- `Invoke-WithStatus` documentation corrected: both helpers run the scriptblock in the main session; the difference is only the spinner.
- Progress bars are suppressed for the duration of the animation (set globally, restored afterwards) so cmdlet progress rendering cannot scroll the animation off its saved cursor position.

### Added

- Private `Test-ConsoleInteractive` helper — detects redirected output, missing consoles (services, task sequences), and the ISE; `Invoke-WithAnimation` and `Invoke-WithStatus` now fall back to plain logging in those hosts instead of throwing on cursor positioning.
- `Test-LogFile -MaxArchives` (default 10) — rotated log archives are now pruned instead of accumulating forever.
- The animation stops itself when another writer moves the console cursor, instead of painting frames over foreign output; the completion indicator falls back to the current line when the saved coordinates are stale.
- Failure outcomes are now logged on the non-interactive code paths of both helpers.

### Fixed

- Console foreground color race between animation frames and main-thread output — frames now save and restore the color instead of resetting it.

## [2.0.8] - 2026-03-27

### Changed

- `[BREAKING]` Renamed module from `PSWriteLog` to `MEMZone.WriteLog`.
- `[BREAKING]` Renamed `Initialize-PSWriteLog` to `Initialize-WriteLog`.
- Build script supports `-VersionBump Patch|Minor|Major` to update the manifest version before building.

### Added

- Automatic GitHub Release creation on tag push.
- `VersionBump` parameter in build script (`Major`, `Minor`, `Patch`) to auto-update the manifest version.
- `Last Modified` date in compiled module header, auto-set at build time.
- `Module Version` in compiled module header, auto-synced from manifest at build time.

### Fixed

- Single-character table cell values (e.g. ✓, ✗) are now centered within the column.
- `Write-LogBuffer` no longer warns on module import when log path is not yet initialized.
- Pester `PassThru` configuration for reliable test result reporting.
- GitHub Actions upgraded to Node.js 24 (`actions/checkout@v5`, `actions/upload-artifact@v5`).

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
