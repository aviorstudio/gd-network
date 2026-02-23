# Changelog

## [0.2.0] - 2026-02-22

### Changed
- Refined network module boundaries and removed game-specific serialization coupling.
- Expanded websocket/rate-limit/windowing behavior to match hardened API expectations.

### Added
- New addon tests for HTTP pool, retry backoff, and network windowing.
- `run_tests.sh` headless test runner.
