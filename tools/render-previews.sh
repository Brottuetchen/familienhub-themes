#!/bin/sh
# Renders preview-light.png and preview-dark.png for gallery themes with the
# public Familienhub app (golden tests, fictional demo family, no real data).
#
# Usage: tools/render-previews.sh [theme-folder ...]   (default: every folder with a theme.json)
# Needs: git, Flutter (FLUTTER_ROOT is detected from `flutter` if unset).
set -e
GALLERY="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${FH_WORKDIR:-$(mktemp -d)}"
REPO="${FH_REPO:-https://github.com/Brottuetchen/familienhub.git}"

if [ -z "$FLUTTER_ROOT" ]; then
  FLUTTER_ROOT="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")"
  export FLUTTER_ROOT
fi

if [ ! -d "$WORK/familienhub/.git" ]; then
  git clone --depth 1 "$REPO" "$WORK/familienhub"
fi
APP="$WORK/familienhub/app"

THEMES="$*"
if [ -z "$THEMES" ]; then
  THEMES="$(cd "$GALLERY" && for d in */; do if [ -f "$d/theme.json" ]; then echo "${d%/}"; fi; done)"
fi

# Reuse the demo backend of the app's own screenshot generator: keep everything
# above its main() and append our own main().
SRC="$APP/test_screenshots/screenshots_test.dart"
OUT="$APP/test_screenshots/gallery_test.dart"
sed '/^void main() {/,$d' "$SRC" > "$OUT"
cat >> "$OUT" <<'DART'
/// Same as the server's _merge_style (backend/app/routers/themes.py): a variant only changes what it
/// sets; background and card are merged field by field. Without this, variants lose the base style.
Map<String, dynamic> _mergeStyle(Map<String, dynamic> base, Map<String, dynamic>? override) {
  if (override == null) return {...base};
  final merged = {...base, ...override};
  for (final key in ['background', 'card']) {
    if (base[key] is Map && override[key] is Map) {
      merged[key] = {...(base[key] as Map).cast<String, dynamic>(), ...(override[key] as Map).cast<String, dynamic>()};
    }
  }
  return merged;
}

ThemeSpec _galleryTheme(String dir) {
  final raw = jsonDecode(File('$dir/theme.json').readAsStringSync()) as Map<String, dynamic>;
  final base = (raw['style'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final variants = (raw['variants'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  return ThemeSpec.fromJson({
    'id': 'gallery:${dir.split('/').last}',
    'builtin': false,
    ...raw,
    'variants': {
      for (final e in variants.entries)
        e.key: {
          ...(e.value as Map).cast<String, dynamic>(),
          'style': _mergeStyle(base, ((e.value as Map)['style'] as Map?)?.cast<String, dynamic>()),
        },
    },
  });
}

void main() {
  final gallery = Platform.environment['GALLERY_DIR']!;
  final themes = Platform.environment['GALLERY_THEMES']!.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
  setUp(() async {
    await setUpTestEnv();
    await _loadFonts();
  });
  tearDown(() => setAppLanguage('de'));

  for (final id in themes) {
    for (final mode in ['light', 'dark']) {
      testWidgets('$id/$mode', (tester) async {
        setAppLanguage('en');
        tester.platformDispatcher.localeTestValue = const Locale('en');
        tester.view.physicalSize = const Size(780, 1688); // 390 x 844 at 2x
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final brightness = mode == 'dark' ? Brightness.dark : Brightness.light;
        final theme = AppTheme.fromSpec(_galleryTheme('$gallery/$id').forBrightness(brightness));
        await tester.pumpWidget(_app(_demo('en'), theme, const MainShell(startPush: false)));
        await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('$gallery/$id/preview-$mode.png'));
      });
    }
  }
}
DART

cd "$APP"
flutter pub get >/dev/null
GALLERY_DIR="$GALLERY" GALLERY_THEMES="$THEMES" flutter test --update-goldens test_screenshots/gallery_test.dart
