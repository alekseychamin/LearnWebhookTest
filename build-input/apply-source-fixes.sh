#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path

root = Path('app/src/main/java/com/openai/folduirescue')

for filename in ('UiSnapshot.java', 'RescueAccessibilityService.java'):
    path = root / filename
    text = path.read_text(encoding='utf-8')
    text = text.replace(
        'AccessibilityNodeInfo.ACTION_SHOW_ON_SCREEN',
        'AccessibilityNodeInfo.AccessibilityAction.ACTION_SHOW_ON_SCREEN.getId()'
    )
    path.write_text(text, encoding='utf-8')

for filename in ('UiTreeDumper.java', 'RescueAccessibilityService.java'):
    path = root / filename
    text = path.read_text(encoding='utf-8')
    text = text.replace('.bounds.flattenToShortString()', '.bounds.toShortString()')
    path.write_text(text, encoding='utf-8')

path = root / 'RescueAccessibilityService.java'
text = path.read_text(encoding='utf-8')
text = text.replace(
    'panelParams.accessibilityTitle = "Fold UI Rescue";',
    'panelParams.setTitle("Fold UI Rescue");'
)
text = text.replace(
    'params.accessibilityTitle = "Диагностика элементов YoloPrice";',
    'params.setTitle("Диагностика элементов YoloPrice");'
)
text = text.replace(
    'panelParams.setAccessibilityTitle("Fold UI Rescue");',
    'panelParams.setTitle("Fold UI Rescue");'
)
text = text.replace(
    'params.setAccessibilityTitle("Диагностика элементов YoloPrice");',
    'params.setTitle("Диагностика элементов YoloPrice");'
)
path.write_text(text, encoding='utf-8')
PY
