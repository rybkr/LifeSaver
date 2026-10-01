#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_bundle="$PWD/build/Build/Products/Release/LifeSaver.saver"
target_bundle="$HOME/Library/Screen Savers/LifeSaver.saver"
/usr/bin/codesign --verify "$source_bundle"
if [[ -d "$target_bundle" ]]; then
    backup_dir=$(mktemp -d "${TMPDIR:-/tmp}/lifesaver-backup.XXXXXX")
    /usr/bin/ditto "$target_bundle" "$backup_dir/LifeSaver.saver"
    printf 'Previous version saved at %s\n' "$backup_dir/LifeSaver.saver"
fi
mkdir -p "$HOME/Library/Screen Savers"
/usr/bin/ditto "$source_bundle" "$target_bundle"
# Retire the old product only after the new bundle was copied successfully.
legacy_bundle="$HOME/Library/Screen Savers/UnixLife.saver"
if [[ -d "$legacy_bundle" ]]; then
    legacy_backup=$(mktemp -d "${TMPDIR:-/tmp}/unixlife-backup.XXXXXX")
    mv "$legacy_bundle" "$legacy_backup/UnixLife.saver"
    printf 'Old UnixLife installation archived at %s\n' "$legacy_backup/UnixLife.saver"
fi
# macOS can retain the previous bundle in memory even after replacement.
# Stop only this user's legacy hosts that have actually loaded LifeSaver.
for host_pid in $(/usr/bin/pgrep -u "$(id -u)" -x legacyScreenSaver || true); do
    loaded_files=$(/usr/sbin/lsof -p "$host_pid" -Fn 2>/dev/null || true)
    case "$loaded_files" in
        *"/LifeSaver.saver/Contents/MacOS/LifeSaver"*|*"/UnixLife.saver/Contents/MacOS/UnixLife"*)
            kill "$host_pid"
            printf 'Restarted LifeSaver host %s\n' "$host_pid"
            ;;
    esac
done
printf 'LifeSaver installed. Start a fresh preview in System Settings.\n'
