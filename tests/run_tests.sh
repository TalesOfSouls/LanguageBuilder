#!/bin/bash
# Tests of language_builder (Linux + Windows, on Windows from Git Bash / the bash of the CI)
#
# Usage: tests/run_tests.sh [path to language_builder]
#     default: ../build/language_builder/language_builder(.exe), build it first with build.sh / build.bat
#
# Test data (tests/data/lang, converted in a copy, the .langbin files are written next to the .langtxt files):
#     general/, en_US/        copies of GameEditor language files (sub directories)
#     syntax.langtxt          comments, quotes, escape sequences, empty value, ':' in the value
#     syntax_crlf.langtxt     the same file with windows line endings -> same .langbin
#     readme.txt, .hidden/    have to be skipped
#
# The .langbin files are compared byte by byte with tests/expected
#
# The exit code is the number of failed tests
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA="$SCRIPT_DIR/data"
EXPECTED="$SCRIPT_DIR/expected"

BIN="$1"
if [ -z "$BIN" ]; then
    BIN="$SCRIPT_DIR/../../build/language_builder/language_builder"
    [ -f "$BIN.exe" ] && BIN="$BIN.exe"
fi

if [ ! -f "$BIN" ]; then
    echo "language_builder not found: $BIN (build it first: build.sh / build.bat)"
    exit 1
fi

native() { if command -v cygpath > /dev/null; then cygpath -w "$1"; else echo "$1"; fi; }

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

PASSED=0
FAILED=0
pass() { PASSED=$((PASSED + 1)); echo "  ok    $1"; }
fail() { FAILED=$((FAILED + 1)); echo "  FAIL  $1"; [ -n "$2" ] && sed 's/^/        /' "$2" | head -20; }
same() { if cmp "$2" "$3" > "$OUT/diff" 2>&1; then pass "$1"; else fail "$1" "$OUT/diff"; fi; }

echo "language_builder tests ($BIN)"

cp -R "$DATA/lang" "$OUT/lang"

if "$BIN" "$(native "$OUT/lang")" > "$OUT/log" 2>&1; then pass "convert directory"; else fail "convert directory (exit code $?)" "$OUT/log"; fi
if grep -q "Language Files 5" "$OUT/log"; then pass "5 language files"; else fail "not 5 language files" "$OUT/log"; fi

for file in en_US/hud en_US/menu general/en_US syntax; do
    same "$file.langbin: expected output" "$EXPECTED/$file.langbin" "$OUT/lang/$file.langbin"
done

same "windows line endings: same output" "$EXPECTED/syntax.langbin" "$OUT/lang/syntax_crlf.langbin"

if [ ! -e "$OUT/lang/.hidden/skipped.langbin" ]; then pass "hidden directory skipped"; else fail "hidden directory converted"; fi
if [ -z "$(find "$OUT/lang" -name 'readme*' ! -name 'readme.txt')" ]; then pass "other files skipped"; else fail "other files converted"; fi

# Errors
if "$BIN" > "$OUT/log" 2>&1; then fail "no arguments (expected an error)" "$OUT/log"; else pass "no arguments"; fi
if "$BIN" "$(native "$OUT/does_not_exist")" > "$OUT/log" 2>&1; then fail "missing directory (expected an error)" "$OUT/log"; else pass "missing directory"; fi

echo "$PASSED passed, $FAILED failed"
exit $FAILED
