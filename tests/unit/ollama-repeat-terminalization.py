#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "patches/ollama/v0.32.0-repeat-limit-terminalization.patch"
EXPECTED_SHA = "4cc8126f2c30401875714fd7974d21389105cf4b018094f5cb3be24f1a803299"


def main() -> None:
    data = PATCH.read_bytes()
    text = data.decode("utf-8")
    assert hashlib.sha256(data).hexdigest() == EXPECTED_SHA
    assert "if tokenRepeat > 30" in text
    assert "DoneReasonRepeatLimit" in text
    assert 'return "repeat_limit"' in text
    assert "return ctx.Err()" in text
    assert "-\t\t\t\treturn ctx.Err()" in text
    assert "+\t\t\t\treturn ctx.Err()" not in text
    assert "TestLlamaServerCompletionRepeatLimitTerminalizes" in text
    assert "TestGenerateHandlerRepeatLimitTerminalization" in text
    assert "TestLlamaServerCompletionCancellationRemainsAnError" in text
    assert "TestLlamaServerCompletionCleanStreamWithoutStopRemainsNonterminal" in text
    assert "devstral" not in text.lower()
    assert "qwen" not in text.lower()
    print("ollama-repeat-terminalization: PASS")


if __name__ == "__main__":
    main()
