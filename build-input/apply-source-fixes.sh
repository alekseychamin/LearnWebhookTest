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

# Reconstruct and validate the 0.2.1 override from small text chunks. The original
# part02 is intentionally not used; it lost one character during an earlier upload.
python3 - <<'PY'
from pathlib import Path
import base64
import hashlib

expected_parts = [
    ('v021-overrides.b64.part00', 'e0cfb0f2575ec5307d203f8517845e4dc43a831c69571112f1639cf415c5940d'),
    ('v021-overrides.b64.part01', '5f9160d498cd6a13d8c4f898b6a79ccea568ae14c42cb7ee9f0ba456780fc38d'),
    ('v021-overrides.b64.part02a', '70c360f8a972666236c34d3b8af67be75091815d2fb89854080575b7051c3f7c'),
    ('v021-overrides.b64.part02b', '141296c8836b8d59db1a3eabf9829d0b3692344a6f37210e8d161d6f86829d85'),
    ('v021-overrides.b64.part03', '815bfb43e671049884312e6b9c70a22cf5262405253fda0d803268d536db0e0d'),
]
chunks = []
for name, expected_sha in expected_parts:
    path = Path('build-input') / name
    data = path.read_bytes()
    actual_sha = hashlib.sha256(data).hexdigest()
    print(f'{path}: bytes={len(data)} sha256={actual_sha}')
    if actual_sha != expected_sha:
        raise SystemExit(f'Checksum mismatch for {name}')
    chunks.append(data)
text = b''.join(chunks)
actual_text_sha = hashlib.sha256(text).hexdigest()
print(f'v021 base64: bytes={len(text)} mod4={len(text) % 4} sha256={actual_text_sha}')
if actual_text_sha != '4b6d624fa2dbc8843455fe47599ecb063fe9fdede88a6fcb462a443d2e098536':
    raise SystemExit('v021 base64 text checksum mismatch')
decoded = base64.b64decode(text, validate=True)
Path('/tmp/folduirescue-v021-overrides.tar.gz').write_bytes(decoded)
PY

echo "82bb9671f63c426e33b841f24c7df08593bb401b7ae8a3100d3f6fc0850d60a1  /tmp/folduirescue-v021-overrides.tar.gz" | sha256sum -c -
tar -xzf /tmp/folduirescue-v021-overrides.tar.gz -C .

test -f app/src/main/java/com/openai/folduirescue/RescueActionResolver.java
grep -q "versionName '0.2.1-beta'" app/build.gradle
grep -q 'Версия 0.2.1-beta' app/src/main/java/com/openai/folduirescue/MainActivity.java
grep -q 'startFirstCardPriming' app/src/main/java/com/openai/folduirescue/RescueAccessibilityService.java
grep -q 'canPrimeFirstCard' app/src/main/java/com/openai/folduirescue/RescueActionResolver.java
