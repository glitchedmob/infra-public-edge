#!/bin/sh
set -eu

[ -s /source/db.sqlite ] || { echo 'Headscale database is not initialized' >&2; exit 1; }
sqlite3 -readonly -bail /source/db.sqlite '.timeout 10000' '.backup /scratch/snapshot/db.sqlite'
sqlite3 -bail /scratch/snapshot/db.sqlite 'PRAGMA journal_mode=DELETE;' >/dev/null
[ "$(sqlite3 -readonly /scratch/snapshot/db.sqlite 'PRAGMA integrity_check;')" = ok ]
cp /source/noise_private.key /source/derp_server_private.key /scratch/snapshot/
if [ -f /source/private.key ]; then
    cp /source/private.key /scratch/snapshot/
fi
