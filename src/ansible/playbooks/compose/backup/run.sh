#!/bin/sh
set -eu
umask 077

# The same lock covers scheduled jobs and one-off Compose runs.
exec 9>/scratch/backup.lock
if ! flock -n 9; then
    echo 'Another backup or maintenance operation is running' >&2
    exit 1
fi

if [ "${1:-}" = schedule ]; then
    rm -rf /scratch/snapshot
    flock -u 9
    exec 9>&-
    exec supercronic /etc/backup/crontab
fi

set -a
. /run/secrets/backup/backup.env
set +a

case "${1:-}" in
    backup)
        trap 'rm -rf /scratch/snapshot' EXIT
        trap 'exit 1' HUP INT TERM
        rm -rf /scratch/snapshot
        mkdir /scratch/snapshot
        /bin/sh /etc/backup/backup.sh

        # Only initialize a missing repository, never an authentication failure.
        if restic cat config >/dev/null; then
            :
        else
            status=$?
            if [ "$status" -ne 10 ]; then
                exit "$status"
            fi
            restic init
        fi
        # Keep the archive name and format used by k8up restores.
        restic backup --host "$BACKUP_APP" --tag compose \
            --stdin-from-command --stdin-filename "${BACKUP_APP}-backup.tar" \
            -- tar -cf - -C /scratch/snapshot .
        ;;
    check)
        restic check --read-data-subset=5%
        ;;
    prune)
        # Leave existing k8up snapshots out of the new retention policy.
        restic forget --host "$BACKUP_APP" --tag compose \
            --keep-last 5 --keep-daily 14 --keep-weekly 4 --prune
        ;;
    *)
        # Explicit repository commands, including snapshots and staged restores.
        exec restic "$@"
        ;;
esac
