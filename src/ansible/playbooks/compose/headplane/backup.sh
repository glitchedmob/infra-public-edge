#!/bin/sh
set -eu

[ -s /source/hp_persist.db ] || { echo 'Headplane database is not initialized' >&2; exit 1; }
sqlite3 -readonly -bail /source/hp_persist.db '.timeout 10000' '.backup /scratch/snapshot/hp_persist.db'
sqlite3 -bail /scratch/snapshot/hp_persist.db 'PRAGMA journal_mode=DELETE;' >/dev/null
[ "$(sqlite3 -readonly /scratch/snapshot/hp_persist.db 'PRAGMA integrity_check;')" = ok ]
for path in /source/* /source/.[!.]* /source/..?*; do
    [ -e "$path" ] || [ -L "$path" ] || continue
    case "${path##*/}" in hp_persist.db*) continue ;; esac
    cp -a "$path" /scratch/snapshot/
done
