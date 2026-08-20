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

cat build-input/v021-overrides.b64 | base64 --decode > /tmp/folduirescue-v021-overrides.tar.gz
echo "82bb9671f63c426e33b841f24c7df08593bb401b7ae8a3100d3f6fc0850d60a1  /tmp/folduirescue-v021-overrides.tar.gz" | sha256sum -c -
tar -xzf /tmp/folduirescue-v021-overrides.tar.gz -C .

test -f app/src/main/java/com/openai/folduirescue/RescueActionResolver.java
grep -q "versionName '0.2.1-beta'" app/build.gradle
grep -q 'Версия 0.2.1-beta' app/src/main/java/com/openai/folduirescue/MainActivity.java
grep -q 'startFirstCardPriming' app/src/main/java/com/openai/folduirescue/RescueAccessibilityService.java
grep -q 'canPrimeFirstCard' app/src/main/java/com/openai/folduirescue/RescueActionResolver.java
