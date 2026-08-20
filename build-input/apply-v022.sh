#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import base64
import hashlib

BASE64_ALPHABET = b'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='
EXPECTED_PARTS = [
    ('v022-overrides.b64.part00', 8192, '7abe0211386a5457a4960b9688229bbda9ffecf3cbaa19df0b70c0230e24e00c'),
    ('v022-overrides.b64.part01', 8192, 'fd8862819cf87c078303259bbf3d2031c50baee34e13e3c55a1626e28742175f'),
    ('v022-overrides.b64.part02', 8192, '35ff1103cb9778ca7fbcfd5712f12a2f0e319e00b7f97aea252c0a5909e2bf16'),
    ('v022-overrides.b64.part03', 8192, 'f925b1de64481a487cb0ab82ec9df1e7fbd32dd2497a4657ebe6b689b513ac8f'),
    ('v022-overrides.b64.part04', 1188, '307d493826989da9bb392d386a11f734fd6f00ae2b4bda6b3e075c0e83495512'),
]
EXPECTED_TEXT_SHA = '0806fb2bf3c84f5bab4bfbc08d3ad6eba8893737ec2a864b9aafa3f38d63f52a'
EXPECTED_ARCHIVE_SHA = 'dd7f13824abf035486e35c41fb2cc2fd7e490efce730b2bba3f2261bd1f07f89'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def repair_one_missing_byte(data: bytes, expected_length: int, expected_sha: str, name: str) -> bytes:
    if len(data) != expected_length - 1:
        raise SystemExit(
            f'Checksum mismatch for {name}; size {len(data)} cannot be repaired as one missing byte')
    for position in range(len(data) + 1):
        prefix = data[:position]
        suffix = data[position:]
        for value in BASE64_ALPHABET:
            candidate = prefix + bytes((value,)) + suffix
            if sha(candidate) == expected_sha:
                print(f'Recovered one missing base64 character in {name}: '
                      f'position={position}, value={chr(value)!r}')
                return candidate
    raise SystemExit(f'Unable to checksum-repair {name}')


chunks = []
for name, expected_length, expected_sha in EXPECTED_PARTS:
    path = Path('build-input') / name
    data = path.read_bytes()
    actual_sha = sha(data)
    print(f'{path}: bytes={len(data)} sha256={actual_sha}')
    if actual_sha != expected_sha:
        data = repair_one_missing_byte(data, expected_length, expected_sha, name)
    if len(data) != expected_length or sha(data) != expected_sha:
        raise SystemExit(f'Final checksum mismatch for {name}')
    chunks.append(data)

text = b''.join(chunks)
actual_text_sha = sha(text)
print(f'v022 base64: bytes={len(text)} mod4={len(text) % 4} sha256={actual_text_sha}')
if actual_text_sha != EXPECTED_TEXT_SHA:
    raise SystemExit('v022 base64 text checksum mismatch')

decoded = base64.b64decode(text, validate=True)
actual_archive_sha = sha(decoded)
print(f'v022 archive: bytes={len(decoded)} sha256={actual_archive_sha}')
if actual_archive_sha != EXPECTED_ARCHIVE_SHA:
    raise SystemExit('v022 archive checksum mismatch')
Path('/tmp/folduirescue-v022-overrides.tar.gz').write_bytes(decoded)
PY

tar -xzf /tmp/folduirescue-v022-overrides.tar.gz -C .

test -f app/src/main/java/com/openai/folduirescue/RescueActionResolver.java
grep -q "versionCode 5" app/build.gradle
grep -q "versionName '0.2.2-beta'" app/build.gradle
grep -q 'Версия 0.2.2-beta' app/src/main/java/com/openai/folduirescue/MainActivity.java
grep -q 'CURRENT_CARD_PROXY' app/src/main/java/com/openai/folduirescue/RescueAccessibilityService.java
grep -q 'actionsMatchCurrentCard' app/src/main/java/com/openai/folduirescue/RescueActionResolver.java
