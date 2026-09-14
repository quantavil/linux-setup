"""Offline conversion of secrets written by GNOME Keyring 50's broken writer.

Only for a known unpatched writer, while the service is stopped. The installer
backs up the whole directory first. This is NOT a general keyring converter:
running it on correctly escaped textual secrets would change their values.
"""
import configparser
import os
from pathlib import Path
import re
import sys
import tempfile

from gi.repository import GLib


def convert(data: bytes) -> tuple[bytes, int]:
    if not data.startswith(b"[keyring]\n") or b"\0" in data:
        raise ValueError("Expected an unencrypted textual keyring")
    # The affected writer emits secret, mtime, ctime consecutively. Use this
    # exact boundary, not arbitrary newlines or section-looking secret data.
    pattern = re.compile(rb"^secret=(.*?)(?=\nmtime=[0-9]+\nctime=[0-9]+(?:\n|$))", re.M | re.S)
    matches = list(pattern.finditer(data))
    if len(matches) != len(re.findall(rb"^secret=", data, re.M)):
        raise ValueError("Ambiguous secret boundaries; original retained")
    for match in matches:
        if re.search(rb"\n(?:mtime=|ctime=|\[)", match[1]):
            raise ValueError("Ambiguous multiline secret; original retained")
    converted = pattern.sub(lambda m: b"binary-secret=" + m[1].hex().encode("ascii"), data)
    keyfile = GLib.KeyFile()
    text = converted.decode("utf-8")
    # GLib accepts duplicate keys. Reject them here so a secret containing a
    # fake mtime/ctime boundary cannot silently become part of the metadata.
    strict = configparser.RawConfigParser(
        delimiters=('=',), comment_prefixes=('#',), empty_lines_in_values=False)
    strict.read_string(text)
    keyfile.load_from_data(text, len(converted), GLib.KeyFileFlags.NONE)
    # Hex encoding is an existing daemon format and preserves every secret byte.
    return converted, len(matches)


def main() -> None:
    path = Path(sys.argv[1])
    if path.is_symlink() or not path.is_file() or path.stat().st_uid != os.getuid():
        raise ValueError("Expected an owned, regular keyring file")
    converted, count = convert(path.read_bytes())
    fd, temporary = tempfile.mkstemp(prefix=".repair-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(converted)
            out.flush()
            os.fsync(out.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        Path(temporary).unlink(missing_ok=True)
    print(f"Converted {count} unescaped textual secrets without printing their contents.")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # GLib parse exceptions can contain the credential-bearing input line.
        print("Keyring repair failed; inspect the private backup. No credential contents were logged.", file=sys.stderr)
        sys.exit(1)
