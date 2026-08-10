#!/usr/bin/env python3
"""Unit checks for the fixed loopback machine-response helper."""

import importlib.machinery
import importlib.util
import json
import pathlib
import tempfile


root = pathlib.Path(__file__).resolve().parents[2]
helper_path = root / "bin" / "ollama-machine-response"
loader = importlib.machinery.SourceFileLoader("ollama_machine_response", str(helper_path))
spec = importlib.util.spec_from_loader("ollama_machine_response", loader)
assert spec and spec.loader
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class FakeResponse:
    def __init__(self, body: bytes):
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self):
        return self.body


def opener_for(body, captured):
    def opener(request, timeout):
        captured["url"] = request.full_url
        captured["timeout"] = timeout
        captured["payload"] = request.data
        return FakeResponse(body)

    return opener


captured = {}
expected = 'line one\n"quotes" and \\\\slashes'.encode("utf-8")
body = json.dumps({"response": expected.decode("utf-8")}).encode("utf-8")
actual = helper.response_bytes("qwen3-coder:30b", "neutral prompt", opener_for(body, captured))
assert actual == expected
assert captured["url"] == "http://127.0.0.1:11434/api/generate"
assert captured["timeout"] == 180
assert json.loads(captured["payload"].decode("utf-8")) == {
    "model": "qwen3-coder:30b",
    "prompt": "neutral prompt",
    "stream": False,
}

for malformed in (b"not-json", b"[]", b"{}", b'{"response":""}'):
    try:
        helper.response_bytes("qwen3-coder:30b", "neutral", opener_for(malformed, {}))
    except ValueError:
        pass
    else:
        raise AssertionError(f"malformed response was accepted: {malformed!r}")

with tempfile.TemporaryDirectory() as temp:
    output = pathlib.Path(temp) / "response.txt"
    original = helper.response_bytes
    helper.response_bytes = lambda *_args: b'{"probe":"exact"}'
    try:
        assert helper.main(["--model", "qwen3-coder:30b", "--prompt", "neutral", "--output", str(output)]) == 0
    finally:
        helper.response_bytes = original
    assert output.read_bytes() == b'{"probe":"exact"}'

print("ollama-machine-response: PASS")
