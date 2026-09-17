#!/usr/bin/env python3
"""Extract an application backup into a new directory and check its SQLite data."""

import argparse
from pathlib import Path, PurePosixPath
import shutil
import sqlite3
import tarfile


def extract_archive(archive, destination, database, required_files):
    if archive.is_symlink() or not archive.is_file():
        raise ValueError("Expected a regular backup archive")
    if destination.exists() or destination.is_symlink():
        raise ValueError("Restore staging directory already exists")

    with tarfile.open(archive, mode="r:") as backup:
        members = backup.getmembers()
        seen = set()
        for member in members:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts:
                raise ValueError(f"Unsafe archive path: {member.name}")
            if not (member.isfile() or member.isdir()):
                raise ValueError(f"Unsupported archive entry: {member.name}")
            if path in seen or (path == PurePosixPath(".") and not member.isdir()):
                raise ValueError(f"Duplicate or invalid archive entry: {member.name}")
            seen.add(path)
        required_space = sum(member.size for member in members if member.isfile())
        if required_space > shutil.disk_usage(destination.parent).free:
            raise ValueError("Insufficient disk space to extract the backup")

        destination.mkdir(mode=0o700)
        # Only regular files and directories are allowed; never restore archive ownership.
        for member in members:
            path = destination / member.name
            if member.isdir():
                path.mkdir(mode=0o700, parents=True, exist_ok=True)
            else:
                path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                with backup.extractfile(member) as source, path.open("xb") as target:
                    shutil.copyfileobj(source, target)
                path.chmod(0o600 | (member.mode & 0o100))

    for filename in [database, *required_files]:
        path = destination / filename
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"Required backup file is missing or empty: {filename}")
    for suffix in ["-wal", "-shm", "-journal"]:
        if (destination / (database + suffix)).exists():
            raise ValueError("Expected a standalone SQLite backup without journal files")
    database_path = destination / database
    with database_path.open("rb") as source:
        if source.read(16) != b"SQLite format 3\x00":
            raise ValueError("Invalid SQLite database header")
    connection = sqlite3.connect(database_path.resolve().as_uri() + "?mode=ro", uri=True)
    try:
        if connection.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
            raise ValueError("SQLite integrity check failed")
    finally:
        connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("database")
    parser.add_argument("required_files", nargs="*")
    args = parser.parse_args()
    extract_archive(args.archive, args.destination, args.database, args.required_files)
    print("Archive and SQLite integrity checks passed")


if __name__ == "__main__":
    main()
