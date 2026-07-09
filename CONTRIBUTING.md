# Contributing to HarbourBuilder

Thank you for your interest in improving HarbourBuilder!

## Development Setup

1. Clone the repo.
2. For Windows: run `build_win.bat` (it now auto-detects Harbour in common locations).
3. Use `clean.bat` (or `./clean.sh`) to remove build artifacts between runs.
4. The main sources live under `source/`.

## Code Style

- Harbour (.prg): 3-space indent preferred (see .editorconfig).
- Keep platform-specific code in the respective `hbbuilder_*.prg` and `backends/`.
- Avoid new absolute paths. Use `GetHbBuilderRoot()`, `HB_DirBase()`, or environment variables.

## Making Changes

- Fix bugs and add features in the visual designer, controls, or backends.
- Update corresponding docs in `docs/`.
- Add or update tests in `tests/`.
- Run `clean.bat` before committing to avoid noise.

## Commit Messages

Follow conventional style:
- `fix:` for bug fixes
- `feat:` for new features
- `chore(review):` for cleanup and improvements

## Android / Mobile

The Android backend is under active development. See `source/backends/android/SETUP.md`.

Pull requests are welcome for:
- Additional controls
- Better cross-platform path handling
- iOS parity
- Bug fixes in the designer or debugger

## License

MIT — see LICENSE.
