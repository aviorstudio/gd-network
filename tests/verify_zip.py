#!/usr/bin/env python3
import stat
import sys
import zipfile
from pathlib import PurePosixPath

archive, manifest_path = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as manifest:
    expected = {line.strip() for line in manifest if line.strip()}
with zipfile.ZipFile(archive) as package:
    seen = set()
    for info in package.infolist():
        if info.is_dir():
            continue
        path = PurePosixPath(info.filename)
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"unsafe archive path: {info.filename}")
        if info.filename in seen:
            raise SystemExit(f"duplicate archive path: {info.filename}")
        seen.add(info.filename)
        if stat.S_ISLNK(info.external_attr >> 16):
            raise SystemExit(f"symlink rejected: {info.filename}")
    if seen != expected:
        raise SystemExit(
            f"closed manifest mismatch: missing={sorted(expected-seen)} unexpected={sorted(seen-expected)}"
        )
print(f"ZIP_MANIFEST_OK files={len(expected)}")
