# Preview renderer

`render-previews.sh` writes `preview-light.png` and `preview-dark.png` (Today tab, English, 390 x 844 logical at 2x) into each theme folder.

It clones the public [Familienhub](https://github.com/Brottuetchen/familienhub) repo (shallow) into a temporary directory, builds a golden test from the app's own `test_screenshots/screenshots_test.dart` (fictional demo family, bundled fonts) and runs it with `flutter test --update-goldens`.

```sh
tools/render-previews.sh              # all themes
tools/render-previews.sh candy-pop    # one theme
FH_WORKDIR=~/fh tools/render-previews.sh   # reuse an existing clone
```

Requirements: `git` and Flutter on `PATH`. Optional: shrink the PNGs losslessly afterwards (for example with `oxipng`).
