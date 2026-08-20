#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path

root = Path('app/src/main/java/com/openai/folduirescue')

# Android API compatibility fixes used by the original diagnostic build.
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
    if not path.exists():
        continue
    text = path.read_text(encoding='utf-8')
    text = text.replace('.bounds.flattenToShortString()', '.bounds.toShortString()')
    path.write_text(text, encoding='utf-8')

service = root / 'RescueAccessibilityService.java'
text = service.read_text(encoding='utf-8')
text = text.replace(
    'panelParams.accessibilityTitle = "Fold UI Rescue";',
    'panelParams.setTitle("Fold UI Rescue");'
)
text = text.replace(
    'params.accessibilityTitle = "Диагностика элементов YoloPrice";',
    'params.setTitle("Диагностика элементов YoloPrice");'
)

# Version 0.1.1: prevent the accessibility overlay from reacting to its own
# window events and entering a show/hide feedback loop on Samsung One UI.
old = '''    private static volatile RescueAccessibilityService instance;\n\n    private final Handler mainHandler = new Handler(Looper.getMainLooper());\n'''
new = '''    private static final long PANEL_VISIBILITY_DEBOUNCE_MS = 180L;\n    private static volatile RescueAccessibilityService instance;\n\n    private final Handler mainHandler = new Handler(Looper.getMainLooper());\n    private final Runnable panelVisibilityRefresh = this::refreshPanelVisibilityFromWindows;\n'''
if old not in text:
    raise SystemExit('Failed to locate service field block')
text = text.replace(old, new, 1)

old = '''        if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED\n                || type == AccessibilityEvent.TYPE_WINDOWS_CHANGED\n                || type == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {\n            if (!packageName.isBlank()) {\n                foregroundPackage = packageName;\n            }\n            updatePanelVisibility();\n        }\n'''
new = '''        if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED\n                || type == AccessibilityEvent.TYPE_WINDOWS_CHANGED) {\n            // Accessibility overlays generate window events themselves. Using the package from\n            // each event created a feedback loop on Samsung One UI: show -> hide -> show.\n            // Resolve the real active TYPE_APPLICATION window after events have settled.\n            schedulePanelVisibilityRefresh();\n        }\n'''
if old not in text:
    raise SystemExit('Failed to locate accessibility event visibility block')
text = text.replace(old, new, 1)

old = '''    public void onDestroy() {\n        removeDialog();\n'''
new = '''    public void onDestroy() {\n        mainHandler.removeCallbacks(panelVisibilityRefresh);\n        removeDialog();\n'''
if old not in text:
    raise SystemExit('Failed to locate onDestroy block')
text = text.replace(old, new, 1)

old = '''    public void onConfigurationChanged(Configuration newConfig) {\n        super.onConfigurationChanged(newConfig);\n        if (panelView != null) {\n            removePanel();\n            mainHandler.postDelayed(this::syncSessionUi, 250);\n        }\n    }\n\n    void syncSessionUi() {\n        if (SessionManager.isActive(this)) {\n            if (TARGET_PACKAGE.equals(foregroundPackage) || foregroundPackage.isBlank()) {\n                showPanel();\n            }\n        } else {\n            removeDialog();\n            removePanel();\n        }\n        broadcastState();\n    }\n'''
new = '''    public void onConfigurationChanged(Configuration newConfig) {\n        super.onConfigurationChanged(newConfig);\n        // Fold/unfold can emit several configuration callbacks. Recreate once after the\n        // display metrics settle instead of repeatedly showing and hiding the panel.\n        mainHandler.removeCallbacks(panelVisibilityRefresh);\n        removeDialog();\n        removePanel();\n        schedulePanelVisibilityRefresh(300L);\n    }\n\n    void syncSessionUi() {\n        if (SessionManager.isActive(this)) {\n            schedulePanelVisibilityRefresh(80L);\n        } else {\n            mainHandler.removeCallbacks(panelVisibilityRefresh);\n            removeDialog();\n            removePanel();\n        }\n        broadcastState();\n    }\n'''
if old not in text:
    raise SystemExit('Failed to locate configuration/session UI block')
text = text.replace(old, new, 1)

old = '''            toast(result ? "ACTION_CLICK принят Android" : "ACTION_CLICK не выполнен");\n            mainHandler.postDelayed(() -> requestCheckpoint(\n                    "after_click_" + safeReason,\n                    null), 1_100);\n'''
new = '''            toast(result ? "ACTION_CLICK принят Android" : "ACTION_CLICK не выполнен");\n            mainHandler.postDelayed(() -> {\n                if (isTargetApplicationActive()) {\n                    requestCheckpoint("after_click_" + safeReason, null);\n                }\n            }, 1_100);\n'''
if old not in text:
    raise SystemExit('Failed to locate post-click checkpoint block')
text = text.replace(old, new, 1)

old = '''    private void restoreOverlayAfterCapture() {\n        if (dialogView != null) {\n            dialogView.setVisibility(View.VISIBLE);\n        }\n        if (panelView != null) {\n            panelView.setVisibility(View.VISIBLE);\n        } else {\n            updatePanelVisibility();\n        }\n    }\n\n    private void updatePanelVisibility() {\n        if (!SessionManager.isActive(this)) {\n            removePanel();\n            return;\n        }\n        if (TARGET_PACKAGE.equals(foregroundPackage)) {\n            showPanel();\n            if (panelView != null) {\n                panelView.setVisibility(View.VISIBLE);\n            }\n        } else if (panelView != null && dialogView == null) {\n            panelView.setVisibility(View.GONE);\n        }\n    }\n'''
new = '''    private void restoreOverlayAfterCapture() {\n        boolean targetActive = isTargetApplicationActive();\n        if (dialogView != null) {\n            dialogView.setVisibility(targetActive ? View.VISIBLE : View.GONE);\n        }\n        if (panelView != null) {\n            panelView.setVisibility(targetActive ? View.VISIBLE : View.GONE);\n        } else {\n            schedulePanelVisibilityRefresh(40L);\n        }\n    }\n\n    private void schedulePanelVisibilityRefresh() {\n        schedulePanelVisibilityRefresh(PANEL_VISIBILITY_DEBOUNCE_MS);\n    }\n\n    private void schedulePanelVisibilityRefresh(long delayMs) {\n        mainHandler.removeCallbacks(panelVisibilityRefresh);\n        mainHandler.postDelayed(panelVisibilityRefresh, Math.max(0L, delayMs));\n    }\n\n    private void refreshPanelVisibilityFromWindows() {\n        if (!SessionManager.isActive(this)) {\n            removeDialog();\n            removePanel();\n            return;\n        }\n        if (captureInProgress.get()) {\n            return;\n        }\n\n        String resolvedPackage = resolveForegroundApplicationPackage();\n        if (resolvedPackage.isBlank()) {\n            // During a brief window rebuild, keep the current state rather than blinking.\n            return;\n        }\n        foregroundPackage = resolvedPackage;\n        updatePanelVisibility();\n    }\n\n    private String resolveForegroundApplicationPackage() {\n        List<AccessibilityWindowInfo> windows = getWindows();\n        String focusedPackage = "";\n        String fallbackPackage = "";\n        if (windows != null) {\n            for (AccessibilityWindowInfo window : windows) {\n                if (window == null\n                        || window.getType() != AccessibilityWindowInfo.TYPE_APPLICATION) {\n                    continue;\n                }\n                AccessibilityNodeInfo root = window.getRoot();\n                if (root == null) {\n                    continue;\n                }\n                String packageName;\n                try {\n                    packageName = JsonUtil.asString(root.getPackageName());\n                } finally {\n                    root.recycle();\n                }\n                if (packageName.isBlank()) {\n                    continue;\n                }\n                if (fallbackPackage.isBlank()) {\n                    fallbackPackage = packageName;\n                }\n                if (window.isActive()) {\n                    return packageName;\n                }\n                if (window.isFocused()) {\n                    focusedPackage = packageName;\n                }\n            }\n        }\n        if (!focusedPackage.isBlank()) {\n            return focusedPackage;\n        }\n        if (!fallbackPackage.isBlank()) {\n            return fallbackPackage;\n        }\n\n        AccessibilityNodeInfo activeRoot = getRootInActiveWindow();\n        if (activeRoot == null) {\n            return "";\n        }\n        try {\n            return JsonUtil.asString(activeRoot.getPackageName());\n        } finally {\n            activeRoot.recycle();\n        }\n    }\n\n    private boolean isTargetApplicationActive() {\n        String resolvedPackage = resolveForegroundApplicationPackage();\n        if (!resolvedPackage.isBlank()) {\n            foregroundPackage = resolvedPackage;\n        }\n        return TARGET_PACKAGE.equals(foregroundPackage);\n    }\n\n    private void updatePanelVisibility() {\n        if (!SessionManager.isActive(this)) {\n            removeDialog();\n            removePanel();\n            return;\n        }\n        if (captureInProgress.get()) {\n            return;\n        }\n        if (TARGET_PACKAGE.equals(foregroundPackage)) {\n            showPanel();\n            if (panelView != null && panelView.getVisibility() != View.VISIBLE) {\n                panelView.setVisibility(View.VISIBLE);\n            }\n        } else if (panelView != null\n                && dialogView == null\n                && panelView.getVisibility() != View.GONE) {\n            panelView.setVisibility(View.GONE);\n        }\n    }\n'''
if old not in text:
    raise SystemExit('Failed to locate overlay visibility block')
text = text.replace(old, new, 1)
service.write_text(text, encoding='utf-8')

build = Path('app/build.gradle')
text = build.read_text(encoding='utf-8')
text = text.replace('versionCode 1', 'versionCode 2')
text = text.replace("versionName '0.1.0-diagnostic'", "versionName '0.1.1-diagnostic'")
build.write_text(text, encoding='utf-8')

main = root / 'MainActivity.java'
text = main.read_text(encoding='utf-8')
text = text.replace('Версия 0.1.0-diagnostic', 'Версия 0.1.1-diagnostic')
main.write_text(text, encoding='utf-8')

readme = Path('README.md')
text = readme.read_text(encoding='utf-8')
text = text.replace('diagnostic 0.1', 'diagnostic 0.1.1', 1)
text += ('\n\n## 0.1.1\n\n'
         'Исправлено постоянное мерцание плавающей панели на Samsung One UI. '
         'Панель больше не принимает собственные accessibility-события за смену активного приложения.\n')
readme.write_text(text, encoding='utf-8')
PY
