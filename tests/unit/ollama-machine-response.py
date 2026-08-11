#!/usr/bin/env python3
"""Unit checks for bounded Ollama envelope and response evidence."""

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


def opener_for(body, captured=None):
    captured = {} if captured is None else captured
    def opener(request, timeout):
        captured["url"] = request.full_url
        captured["timeout"] = timeout
        captured["payload"] = request.data
        return FakeResponse(body)
    return opener


def envelope(done=True, done_reason="stop"):
    return {
        "model": "qwen3-coder:30b",
        "response": 'line one\n"quotes" and \\\\slashes',
        "done": done,
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
    source = envelope(done_reason=reason)
    response, metadata_bytes, outcome = helper.response_and_metadata(
        "qwen3-coder:30b", "neutral prompt",
        opener_for(json.dumps(source).encode(), captured),
    )
    metadata = json.loads(metadata_bytes)
    assert outcome == "TERMINAL"
    assert response == source["response"].encode()
    assert metadata["evidence_contract"] == "OLLAMA_RESPONSE_META_V2"
    assert metadata["done_present"] is True and metadata["done"] is True
    assert metadata["done_reason_present"] is True
    assert metadata["done_reason"] == reason
    assert metadata["response_byte_count"] == len(response)
    assert metadata["prompt_eval_count_present"] is True
    assert metadata["prompt_eval_count"] == 17
    assert metadata["eval_count_present"] is True
    assert metadata["eval_count"] == 23
    assert metadata["outcome_classification"] is None
    assert captured["url"] == "http://127.0.0.1:11434/api/generate"
    assert json.loads(captured["payload"].decode()) == {
        "model": "qwen3-coder:30b", "prompt": "neutral prompt", "stream": False,
    }

repeat = envelope(done_reason="repeat_limit")
response, metadata_bytes, outcome = helper.response_and_metadata(
    "qwen3-coder:30b", "neutral prompt", opener_for(json.dumps(repeat).encode())
)
metadata = json.loads(metadata_bytes)
assert outcome == "REPEAT_LIMIT"
assert response == repeat["response"].encode()
assert metadata["done"] is True
assert metadata["done_reason"] == "repeat_limit"
assert metadata["failure_classification"] is None
assert metadata["outcome_classification"] == "MODEL_REPEAT_LIMIT"

nonterminal = envelope(done=False)
response, metadata_bytes, outcome = helper.response_and_metadata(
    "qwen3-coder:30b", "neutral", opener_for(json.dumps(nonterminal).encode())
)
metadata = json.loads(metadata_bytes)
assert outcome == "NONTERMINAL"
assert response == nonterminal["response"].encode()
assert metadata["done_present"] is True and metadata["done"] is False
assert metadata["failure_classification"] == "OLLAMA_NONTERMINAL_RESPONSE"

missing_done = envelope()
del missing_done["done"]
response, metadata_bytes, outcome = helper.response_and_metadata(
    "qwen3-coder:30b", "neutral", opener_for(json.dumps(missing_done).encode())
)
metadata = json.loads(metadata_bytes)
assert outcome == "DONE_MISSING"
assert response == missing_done["response"].encode()
assert metadata["done_present"] is False and metadata["done"] is None
assert metadata["failure_classification"] == "OLLAMA_DONE_FIELD_MISSING"

optional_absent = envelope()
for field in helper.OPTIONAL_NUMERIC_FIELDS:
    del optional_absent[field]
_, metadata_bytes, outcome = helper.response_and_metadata(
    "qwen3-coder:30b", "neutral", opener_for(json.dumps(optional_absent).encode())
)
metadata = json.loads(metadata_bytes)
assert outcome == "TERMINAL"
for field in helper.OPTIONAL_NUMERIC_FIELDS:
    assert metadata[f"{field}_present"] is False
    assert metadata[field] is None

for body, classification in (
    (b"not-json", "OLLAMA_MALFORMED_ENVELOPE"),
    (b"[]", "OLLAMA_ENVELOPE_NOT_OBJECT"),
    (json.dumps({key: value for key, value in envelope().items() if key != "response"}).encode(), "OLLAMA_RESPONSE_MISSING_OR_EMPTY"),
    (json.dumps({**envelope(), "response": ""}).encode(), "OLLAMA_RESPONSE_MISSING_OR_EMPTY"),
    (json.dumps({**envelope(), "done": "true"}).encode(), "OLLAMA_DONE_FIELD_INVALID"),
):
    response, metadata_bytes, outcome = helper.response_and_metadata(
        "qwen3-coder:30b", "neutral", opener_for(body)
    )
    assert outcome == "INVALID"
    assert json.loads(metadata_bytes)["failure_classification"] == classification


def run_main(outcome, expected_exit):
    with tempfile.TemporaryDirectory() as temporary:
        root = pathlib.Path(temporary)
        output = root / "response.txt"
        partial = root / "partial-response.txt"
        metadata = root / "ollama-envelope-meta.json"
        original = helper.response_and_metadata
        helper.response_and_metadata = lambda *_args: (
            b'{"probe":"exact"}',
            b'{"evidence_contract":"OLLAMA_RESPONSE_META_V2"}\n',
            outcome,
        )
        try:
            actual = helper.main([
                "--model", "qwen3-coder:30b", "--prompt", "neutral",
                "--output", str(output), "--partial-output", str(partial),
                "--metadata-output", str(metadata),
            ])
        finally:
            helper.response_and_metadata = original
        assert actual == expected_exit
        assert metadata.read_bytes() == b'{"evidence_contract":"OLLAMA_RESPONSE_META_V2"}\n'
        if outcome == "TERMINAL":
            assert output.read_bytes() == b'{"probe":"exact"}'
            assert not partial.exists()
        else:
            assert partial.read_bytes() == b'{"probe":"exact"}'
            assert not output.exists()


run_main("TERMINAL", 0)
run_main("NONTERMINAL", helper.EXIT_NONTERMINAL)
run_main("DONE_MISSING", helper.EXIT_DONE_MISSING)
run_main("REPEAT_LIMIT", helper.EXIT_REPEAT_LIMIT)

print("ollama-machine-response: PASS")
