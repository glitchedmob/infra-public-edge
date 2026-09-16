#!/bin/sh
set -eu

[ -s /source/kuma.db ] || { echo 'Uptime Kuma database is not initialized' >&2; exit 1; }
sqlite3 -readonly -bail /source/kuma.db '.timeout 10000' '.backup /scratch/snapshot/kuma.db'
sqlite3 -bail /scratch/snapshot/kuma.db 'PRAGMA journal_mode=DELETE;' >/dev/null
[ "$(sqlite3 -readonly /scratch/snapshot/kuma.db 'PRAGMA integrity_check;')" = ok ]
for path in /source/* /source/.[!.]* /source/..?*; do
    [ -e "$path" ] || [ -L "$path" ] || continue
    case "${path##*/}" in kuma.db*) continue ;; esac
    cp -a "$path" /scratch/snapshot/
done
