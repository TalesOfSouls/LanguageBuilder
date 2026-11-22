# LanguageBuilder

Converts every `.langtxt` file of a directory (recursive, hidden files/directories are skipped) into a `.langbin` file
next to it (format @see `cOMS/localization/Language.cpp`).

```
language_builder <directory>
```

The exit code is 1 if a file couldn't be converted.

## Build

`build.bat [-d|-r]` (Windows, MSVC, x64/arm64) or `build.sh [-d|-r]` (Linux, g++, x86_64/aarch64), output `../build/language_builder/`.
Needs cOMS next to this repository (`../cOMS`).

## Tests

`bash tests/run_tests.sh [path to language_builder]` converts a copy of `tests/data/lang` and compares the `.langbin`
files byte by byte with `tests/expected` (incl. a file with windows line endings that has to give the same output).
The GitHub workflow runs it on Windows + Linux, x64 + arm64, debug + release.
