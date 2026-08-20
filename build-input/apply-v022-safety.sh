#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path

path = Path('app/src/main/java/com/openai/folduirescue/RescueAccessibilityService.java')
text = path.read_text(encoding='utf-8')
old = '''            boolean ownerMatchesKnownCard = !action.originFingerprint.isBlank()\n                    && result.actionsMatchCard(action.originFingerprint);\n            boolean ownerAdvancedAfterCommand = action.originFingerprint.isBlank()\n                    && scrollEventObserved\n                    && scrollPositionChanged\n                    && result.hasPrimary()\n                    && (action.previousOwnerFingerprint.isBlank()\n                    || !action.previousOwnerFingerprint.equals(result.actionOwnerFingerprint)\n                    || SystemClock.elapsedRealtime() - action.startedAt >= 520L);\n'''
new = '''            boolean ownerChangedAfterCommand = !result.actionOwnerFingerprint.isBlank()\n                    && (action.previousOwnerFingerprint.isBlank()\n                    || !action.previousOwnerFingerprint.equals(result.actionOwnerFingerprint));\n            boolean ownerMatchesKnownCard = !action.originFingerprint.isBlank()\n                    && ownerChangedAfterCommand\n                    && result.actionsMatchCard(action.originFingerprint);\n            boolean ownerAdvancedAfterCommand = action.originFingerprint.isBlank()\n                    && scrollEventObserved\n                    && scrollPositionChanged\n                    && result.hasPrimary()\n                    && ownerChangedAfterCommand;\n'''
if old not in text:
    raise SystemExit('Current-card ownership block was not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
PY

grep -q 'ownerChangedAfterCommand' app/src/main/java/com/openai/folduirescue/RescueAccessibilityService.java
if grep -q 'startedAt >= 520L' app/src/main/java/com/openai/folduirescue/RescueAccessibilityService.java; then
  echo 'Unsafe delayed owner fallback is still present' >&2
  exit 1
fi
