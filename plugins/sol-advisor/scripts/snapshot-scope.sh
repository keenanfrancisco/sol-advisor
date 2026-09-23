#!/bin/sh
# Emit a stable content/type/metadata manifest for writable workspace and artifact roots.

set -eu

usage() {
  printf '%s\n' 'Usage: snapshot-scope.sh [--digest] -- PATH [PATH ...]' >&2
  exit 2
}

digest_only=0
if [ "${1-}" = "--digest" ]; then
  digest_only=1
  shift
fi
[ "$#" -ge 2 ] || usage
[ "$1" = "--" ] || usage
shift

exec python3 - "$digest_only" "$@" <<'PY'
import ctypes
import errno
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def digest_file(path: str) -> str:
    digest = hashlib.sha256()
    try:
        with open(path, "rb") as handle:
            while chunk := handle.read(1024 * 1024):
                digest.update(chunk)
    except OSError as error:
        fail(f"could not hash file {path!r}: {error}")
    return digest.hexdigest()


def encode_xattrs(backend: str, entries: list[tuple[bytes, bytes]]) -> dict[str, object]:
    digest = hashlib.sha256()
    for name, value in sorted(entries):
        digest.update(len(name).to_bytes(8, "big"))
        digest.update(name)
        digest.update(len(value).to_bytes(8, "big"))
        digest.update(value)
    return {
        "xattrs_backend": backend,
        "xattr_count": len(entries),
        "xattrs_sha256": digest.hexdigest(),
        "xattrs_supported": True,
    }


def ctypes_xattrs(path: str) -> tuple[str, list[tuple[bytes, bytes]] | None] | None:
    libc = ctypes.CDLL(None, use_errno=True)
    encoded_path = os.fsencode(path)
    unsupported = {errno.ENOTSUP}
    if hasattr(errno, "EOPNOTSUPP"):
        unsupported.add(errno.EOPNOTSUPP)

    if sys.platform == "darwin" and hasattr(libc, "listxattr"):
        nofollow = 0x0001
        list_fn = libc.listxattr
        list_fn.restype = ctypes.c_ssize_t
        list_fn.argtypes = [ctypes.c_char_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
        get_fn = libc.getxattr
        get_fn.restype = ctypes.c_ssize_t
        get_fn.argtypes = [
            ctypes.c_char_p,
            ctypes.c_char_p,
            ctypes.c_void_p,
            ctypes.c_size_t,
            ctypes.c_uint32,
            ctypes.c_int,
        ]

        def list_call(buffer: object, size: int) -> int:
            return list_fn(encoded_path, buffer, size, nofollow)

        def get_call(name: bytes, buffer: object, size: int) -> int:
            return get_fn(encoded_path, name, buffer, size, 0, nofollow)

        backend = "darwin-libc"
    elif hasattr(libc, "llistxattr") and hasattr(libc, "lgetxattr"):
        list_fn = libc.llistxattr
        list_fn.restype = ctypes.c_ssize_t
        list_fn.argtypes = [ctypes.c_char_p, ctypes.c_void_p, ctypes.c_size_t]
        get_fn = libc.lgetxattr
        get_fn.restype = ctypes.c_ssize_t
        get_fn.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_void_p, ctypes.c_size_t]

        def list_call(buffer: object, size: int) -> int:
            return list_fn(encoded_path, buffer, size)

        def get_call(name: bytes, buffer: object, size: int) -> int:
            return get_fn(encoded_path, name, buffer, size)

        backend = "linux-libc"
    else:
        return None

    while True:
        ctypes.set_errno(0)
        names_size = list_call(None, 0)
        if names_size < 0:
            error_number = ctypes.get_errno()
            if error_number in unsupported:
                return backend, None
            fail(f"could not list extended attributes for {path!r}: {os.strerror(error_number)}")
        if names_size == 0:
            names: list[bytes] = []
            break
        names_buffer = ctypes.create_string_buffer(names_size)
        ctypes.set_errno(0)
        names_length = list_call(names_buffer, names_size)
        if names_length < 0 and ctypes.get_errno() == errno.ERANGE:
            continue
        if names_length < 0:
            error_number = ctypes.get_errno()
            fail(f"could not list extended attributes for {path!r}: {os.strerror(error_number)}")
        names = [name for name in names_buffer.raw[:names_length].split(b"\0") if name]
        break

    entries: list[tuple[bytes, bytes]] = []
    for name in names:
        while True:
            ctypes.set_errno(0)
            value_size = get_call(name, None, 0)
            if value_size < 0:
                error_number = ctypes.get_errno()
                fail(f"could not size extended attribute {name!r} for {path!r}: {os.strerror(error_number)}")
            value_buffer = ctypes.create_string_buffer(max(value_size, 1))
            ctypes.set_errno(0)
            value_length = get_call(name, value_buffer, value_size)
            if value_length < 0 and ctypes.get_errno() == errno.ERANGE:
                continue
            if value_length < 0:
                error_number = ctypes.get_errno()
                fail(f"could not read extended attribute {name!r} for {path!r}: {os.strerror(error_number)}")
            entries.append((name, value_buffer.raw[:value_length]))
            break
    return backend, entries


def xattr_evidence(path: str) -> dict[str, object]:
    if not hasattr(os, "listxattr"):
        native_result = ctypes_xattrs(path)
        if native_result is not None:
            backend, entries = native_result
            if entries is None:
                return {"xattrs_backend": backend, "xattrs_supported": False}
            return encode_xattrs(backend, entries)

        xattr_tool = shutil.which("xattr")
        if xattr_tool:
            command = [xattr_tool, "-l", "-x"]
            if os.path.islink(path):
                command.append("-s")
            command.append(path)
            result = subprocess.run(command, check=False, capture_output=True)
            if result.returncode == 0:
                return {
                    "xattrs_backend": "xattr-cli",
                    "xattrs_sha256": digest_bytes(result.stdout),
                    "xattrs_supported": True,
                }
            lowered = result.stderr.lower()
            if b"not supported" in lowered:
                return {"xattrs_backend": "xattr-cli", "xattrs_supported": False}
            detail = result.stderr.decode(errors="replace").strip()
            fail(f"could not read extended attributes for {path!r}: {detail}")

        getfattr_tool = shutil.which("getfattr")
        if getfattr_tool:
            result = subprocess.run(
                [getfattr_tool, "-h", "-d", "-m", "-", "--absolute-names", path],
                check=False,
                capture_output=True,
            )
            if result.returncode == 0:
                return {
                    "xattrs_backend": "getfattr-cli",
                    "xattrs_sha256": digest_bytes(result.stdout),
                    "xattrs_supported": True,
                }
            lowered = result.stderr.lower()
            if b"not supported" in lowered:
                return {"xattrs_backend": "getfattr-cli", "xattrs_supported": False}
            detail = result.stderr.decode(errors="replace").strip()
            fail(f"could not read extended attributes for {path!r}: {detail}")

        fail("no extended-attribute reader is available")

    try:
        names = sorted(os.listxattr(path, follow_symlinks=False), key=os.fsencode)
    except OSError as error:
        unsupported = {errno.ENOTSUP}
        if hasattr(errno, "EOPNOTSUPP"):
            unsupported.add(errno.EOPNOTSUPP)
        if error.errno in unsupported:
            return {"xattrs_supported": False}
        fail(f"could not list extended attributes for {path!r}: {error}")

    entries = []
    for name in names:
        try:
            value = os.getxattr(path, name, follow_symlinks=False)
        except OSError as error:
            fail(f"could not read extended attribute {name!r} for {path!r}: {error}")
        entries.append((os.fsencode(name), value))
    return encode_xattrs("python-os", entries)


def metadata_evidence(path: str, metadata: os.stat_result, record_type: str) -> dict[str, object]:
    record: dict[str, object] = {
        "ctime_ns": metadata.st_ctime_ns,
        "device": metadata.st_dev,
        "gid": metadata.st_gid,
        "inode": metadata.st_ino,
        "mode": stat.S_IMODE(metadata.st_mode),
        "mtime_ns": metadata.st_mtime_ns,
        "nlink": metadata.st_nlink,
        "path": path,
        "size": metadata.st_size,
        "type": record_type,
        "uid": metadata.st_uid,
    }
    if hasattr(metadata, "st_birthtime"):
        record["birthtime_ns"] = int(metadata.st_birthtime * 1_000_000_000)
    if hasattr(metadata, "st_flags"):
        record["flags"] = metadata.st_flags
    if hasattr(metadata, "st_file_attributes"):
        record["file_attributes"] = metadata.st_file_attributes
    if record_type in {"file", "directory", "symlink"}:
        record.update(xattr_evidence(path))
    else:
        record.update({"xattrs_backend": "not-applicable", "xattrs_supported": False})
    return record


records: dict[str, dict[str, object]] = {}


def visit(path: str) -> None:
    normalized = os.path.normpath(path)
    try:
        metadata = os.lstat(normalized)
    except FileNotFoundError:
        records[normalized] = {"path": normalized, "type": "missing"}
        return
    except OSError as error:
        fail(f"could not inspect {normalized!r}: {error}")

    mode = metadata.st_mode
    if stat.S_ISLNK(mode):
        try:
            target = os.readlink(normalized)
        except OSError as error:
            fail(f"could not read symlink {normalized!r}: {error}")
        record = metadata_evidence(normalized, metadata, "symlink")
        record["target_sha256"] = digest_bytes(os.fsencode(target))
        records[normalized] = record
        return

    if stat.S_ISREG(mode):
        record = metadata_evidence(normalized, metadata, "file")
        record["sha256"] = digest_file(normalized)
        records[normalized] = record
        return

    if stat.S_ISDIR(mode):
        records[normalized] = metadata_evidence(normalized, metadata, "directory")
        try:
            children = sorted(os.listdir(normalized))
        except OSError as error:
            fail(f"could not enumerate directory {normalized!r}: {error}")
        for child in children:
            visit(os.path.join(normalized, child))
        return

    record = metadata_evidence(normalized, metadata, "other")
    record["file_type"] = stat.S_IFMT(mode)
    if hasattr(metadata, "st_rdev"):
        record["rdev"] = metadata.st_rdev
    records[normalized] = record


digest_only = sys.argv[1] == "1"

for raw_path in sys.argv[2:]:
    if not raw_path:
        fail("scope paths must be non-empty")
    if raw_path.startswith("-"):
        fail(f"option-like paths must be prefixed with ./ or made absolute: {raw_path}")
    visit(raw_path)

serialized = [
    json.dumps(records[path], ensure_ascii=True, sort_keys=True, separators=(",", ":"))
    for path in sorted(records, key=os.fsencode)
]
if digest_only:
    digest = hashlib.sha256()
    for line in serialized:
        digest.update(line.encode("utf-8"))
        digest.update(b"\n")
    print(digest.hexdigest())
else:
    for line in serialized:
        print(line)
PY
