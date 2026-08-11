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


def envelope(done_reason="stop"):
    return {
        "model": "qwen3-coder:30b",
        "response": 'line one\n"quotes" and \\\\slashes',
        "done": True,
        "done_reason": done_reason,
        "prompt_eval_count": 17,
        "eval_count": 23,
        "total_duration": 101,
        "load_duration": 11,
        "prompt_eval_duration": 31,
        "eval_duration": 59,
    }


for reason in ("stop", "length"):
    captured = {}
    source = envelope(reason)
    response, metadata_bytes = helper.response_and_metadata(
        "qwen3-coder:30b",
        "neutral prompt",
        opener_for(json.dumps(source).encode("utf-8"), captured),
    )
    assert response == source["response"].encode("utf-8")
    metadata = json.loads(metadata_bytes)
    assert metadata == {
        "evidence_contract": "OLLAMA_RESPONSE_META_V1",
        "model": "qwen3-coder:30b",
        "done": True,
        "done_reason_present": True,
        "done_reason": reason,
        "prompt_eval_count": 17,
        "eval_count": 23,
        "total_duration": 101,
        "load_duration": 11,
        "prompt_eval_duration": 31,
        "eval_duration": 59,
    }
    assert captured["url"] == "http://127.0.0.1:11434/api/generate"
    assert captured["timeout"] == 180
    assert json.loads(captured["payload"].decode("utf-8")) == {
        "model": "qwen3-coder:30b",
        "prompt": "neutral prompt",
        "stream": False,
    }

absent_reason = envelope()
del absent_reason["done_reason"]
_, absent_metadata = helper.response_and_metadata(
    "qwen3-coder:30b", "neutral", opener_for(json.dumps(absent_reason).encode(), {})
)
assert json.loads(absent_metadata)["done_reason_present"] is False
assert json.loads(absent_metadata)["done_reason"] is None

invalid_envelopes = [
    b"not-json",
    b"[]",
    b"{}",
    json.dumps({**envelope(), "response": ""}).encode(),
    json.dumps({**envelope(), "done": False}).encode(),
    json.dumps({**envelope(), "done_reason": 7}).encode(),
    json.dumps({**envelope(), "eval_count": "23"}).encode(),
    json.dumps({**envelope(), "model": "different"}).encode(),
]
for malformed in invalid_envelopes:
    try:
        helper.response_and_metadata(
            "qwen3-coder:30b", "neutral", opener_for(malformed, {})
        )
    except ValueError:
        pass
    else:
        raise AssertionError(f"malformed response was accepted: {malformed!r}")

with tempfile.TemporaryDirectory() as temp:
    output = pathlib.Path(temp) / "response.txt"
    metadata = pathlib.Path(temp) / "ollama-response-meta.json"
    original = helper.response_and_metadata
    expected_metadata = b'{"evidence_contract":"OLLAMA_RESPONSE_META_V1"}\n'
    helper.response_and_metadata = lambda *_args: (
        b'{"probe":"exact"}', expected_metadata
    )
    try:
        assert helper.main([
            "--model", "qwen3-coder:30b", "--prompt", "neutral",
            "--output", str(output), "--metadata-output", str(metadata),
        ]) == 0
    finally:
        helper.response_and_metadata = original
    assert output.read_bytes() == b'{"probe":"exact"}'
    assert metadata.read_bytes() == expected_metadata

print("ollama-machine-response: PASS")
