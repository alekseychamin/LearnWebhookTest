#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path

root = Path('app/src/main/java/com/openai/folduirescue')

# The retained baseline was authored against a slightly different Android SDK API surface.
# Keep the two compatibility substitutions needed by the unchanged diagnostic classes.
path = root / 'UiSnapshot.java'
text = path.read_text(encoding='utf-8')
text = text.replace(
    'AccessibilityNodeInfo.ACTION_SHOW_ON_SCREEN',
    'AccessibilityNodeInfo.AccessibilityAction.ACTION_SHOW_ON_SCREEN.getId()'
)
path.write_text(text, encoding='utf-8')

path = root / 'UiTreeDumper.java'
text = path.read_text(encoding='utf-8')
text = text.replace('.bounds.flattenToShortString()', '.bounds.toShortString()')
path.write_text(text, encoding='utf-8')
PY

cat build-input/v020-overrides.b64.part* | base64 --decode > /tmp/folduirescue-v020-overrides.tar.gz
echo "7c395dfdc03020e9aee18835ed705bff48039f0fb332c7ab78ac69ee24da2f56  /tmp/folduirescue-v020-overrides.tar.gz" | sha256sum -c -
tar -xzf /tmp/folduirescue-v020-overrides.tar.gz -C .

# Reconstruct and validate the 0.2.1 override from small text chunks.
python3 - <<'PY'
from pathlib import Path
import base64
import hashlib

parts = sorted(Path('build-input').glob('v021-overrides.b64.part*'))
if not parts:
    raise SystemExit('No v021 split files found')
for part in parts:
    data = part.read_bytes()
    print(f'{part}: bytes={len(data)} sha256={hashlib.sha256(data).hexdigest()}')
text = b''.join(part.read_bytes() for part in parts)
print(f'v021 base64: bytes={len(text)} mod4={len(text) % 4} sha256={hashlib.sha256(text).hexdigest()}')
invalid = [(index, value) for index, value in enumerate(text)
           if not (65 <= value <= 90 or 97 <= value <= 122 or 48 <= value <= 57 or value in b"+/=")]
if invalid:
    raise SystemExit(f'Invalid base64 bytes: {invalid[:20]}')
if hashlib.sha256(text).hexdigest() != '4b6d624fa2dbc8843455fe47599ecb063fe9fdede88a6fcb462a443d2e098536':
    raise SystemExit('v021 base64 text checksum mismatch')
try:
    decoded = base64.b64decode(text, validate=True)
except Exception as exc:
    raise SystemExit(f'v021 base64 decode failed: {exc}')
Path('/tmp/folduirescue-v021-overrides.tar.gz').write_bytes(decoded)
PY

echo "82bb9671f63c426e33b841f24c7df08593bb401b7ae8a3100d3f6fc0850d60a1  /tmp/folduirescue-v021-overrides.tar.gz" | sha256sum -c -
tar -xzf /tmp/folduirescue-v021-overrides.tar.gz -C .

test -f app/src/main/java/com/openai/folduirescue/RescueActionResolver.java
grep -q "versionName '0.2.1-beta'" app/build.gradle
grep -q 'Версия 0.2.1-beta' app/src/main/java/com/openai/folduirescue/MainActivity.java
grep -q 'startFirstCardPriming' app/src/main/java/com/openai/folduirescue/RescueAccessibilityService.java
grep -q 'canPrimeFirstCard' app/src/main/java/com/openai/folduirescue/RescueActionResolver.java
