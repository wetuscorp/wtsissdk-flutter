#!/usr/bin/env bash
set -euo pipefail

dart run pigeon --input pigeons/messages.dart
dart format lib/src/messages.g.dart

# Pigeon 26.3.4 deterministically emits two trailing spaces in the Kotlin
# output. Normalize generated Kotlin after every generation so source control
# and CI keep a clean, reproducible artifact without hand-editing the binding.
python3 - android/src/main/kotlin/co/wetus/sdk/flutter/WtsMessages.g.kt <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
normalized = "\n".join(line.rstrip() for line in source.splitlines())
if source.endswith("\n"):
    normalized += "\n"
if source != normalized:
    path.write_text(normalized, encoding="utf-8")
PY
