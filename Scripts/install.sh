#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_bundle="$PWD/build/Build/Products/Release/UnixLife.saver"
target_bundle="$HOME/Library/Screen Savers/UnixLife.saver"
/usr/bin/codesign --verify "$source_bundle"
if [[ -d "$target_bundle" ]]; then
    backup_dir=$(mktemp -d "${TMPDIR:-/tmp}/unixlife-backup.XXXXXX")
    /usr/bin/ditto "$target_bundle" "$backup_dir/UnixLife.saver"
    printf 'Previous version saved at %s\n' "$backup_dir/UnixLife.saver"
fi
mkdir -p "$HOME/Library/Screen Savers"
/usr/bin/ditto "$source_bundle" "$target_bundle"
# macOS can retain the previous bundle in memory even after replacement.
# Stop only this user's legacy hosts that have actually loaded UnixLife.
for host_pid in $(/usr/bin/pgrep -u "$(id -u)" -x legacyScreenSaver || true); do
    loaded_files=$(/usr/sbin/lsof -p "$host_pid" -Fn 2>/dev/null || true)
    case "$loaded_files" in
        *"/UnixLife.saver/Contents/MacOS/UnixLife"*)
            kill "$host_pid"
            printf 'Restarted UnixLife host %s\n' "$host_pid"
            ;;
    esac
done
printf 'UnixLife installed. Start a fresh preview in System Settings.\n'
