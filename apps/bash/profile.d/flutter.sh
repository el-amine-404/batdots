# profile.d/flutter.sh -- Flutter + Dart (bundled).
# shellcheck shell=bash
# Home is encrypted on this box, which breaks Flutter -- install under /opt.
# https://github.com/flutter/flutter/issues/138748
path::prepend "/opt/flutter/bin"
path::prepend "/opt/flutter/bin/cache/dart-sdk/bin"
