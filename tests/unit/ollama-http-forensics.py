#!/usr/bin/env python3
"""Deterministic checks for the bounded Ollama HTTP forensic capture."""

import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile


root = Path(__file__).resolve().parents[2]
helper_path = root / "bin" / "ollama-http-forensics"
loader = importlib.machinery.SourceFileLoader("ollama_http_forensics", str(helper_path))
spec = importlib.util.spec_from_loader("ollama_http_forensics", loader)
assert spec and spec.loader
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class FakeResponse:
    status = 200
    headers = {
        "Content-Type": "application/x-ndjson",
        "Transfer-Encoding": "chunked",
    }

    def __init__(self, body: bytes):
        self.body = body
        self.offset = 0

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self, size=-1):
        if self.offset >= len(self.body):
            return b""
        end = len(self.body) if size < 0 else min(self.offset + size, len(self.body))
        chunk = self.body[self.offset:end]
        self.offset = end
        return chunk


def opener(body: bytes, captured: dict):
    def open_request(request, timeout):
        captured["url"] = request.full_url
        captured["timeout"] = timeout
        captured["payload"] = request.data
        return FakeResponse(body)
    return open_request


prompt = b"exact forensic prompt"
false_payload, false_request = helper.request_payload(prompt, False)
true_payload, true_request = helper.request_payload(prompt, True)
assert set(json.loads(false_payload)) == {"model", "prompt", "stream"}
assert json.loads(false_payload)["stream"] is False
assert json.loads(true_payload)["stream"] is True
assert {key: value for key, value in json.loads(false_payload).items() if key != "stream"} == {
    key: value for key, value in json.loads(true_payload).items() if key != "stream"
}
for field in ("options", "format", "raw", "keep_alive"):
    assert false_request[f"{field}_present"] is False

nonstream_body = b'{"model":"devstral","response":"partial","done":false}'
captured = {}
body, http = helper.fetch_http(false_payload, opener(nonstream_body, captured))
raw, events, concatenated, analysis = helper.analyze_body(body, False)
assert captured["url"] == helper.ENDPOINT
assert captured["timeout"] == helper.TIMEOUT_SECONDS
assert body == nonstream_body
assert http["http_status"] == 200
assert http["content_type"] == "application/x-ndjson"
assert http["content_length_present"] is False
assert len(events) == 1 and events[0]["done"] is False
assert concatenated == b"partial"
assert analysis["terminal_event_present"] is False


class TimeoutResponse(FakeResponse):
    def read(self, size=-1):
        if self.offset == 0:
            self.offset = len(self.body)
            return self.body
        raise TimeoutError("bounded read timeout")


def timeout_opener(request, timeout):
    return TimeoutResponse(b'{"response":"partial","done":false}\n')


timeout_body, timeout_http = helper.fetch_http(true_payload, timeout_opener)
assert timeout_body == b'{"response":"partial","done":false}\n'
assert timeout_http["read_outcome"] == "READ_ERROR"
assert timeout_http["read_error_type"] == "TimeoutError"

stream_body = (
    b'{"response":"first","done":false}\n'
    b'{"response":" second","done":false}\n'
    b'{"response":"","done":true,"done_reason":"stop","eval_count":2}\n'
)
body, http = helper.fetch_http(true_payload, opener(stream_body, {}))
raw, events, concatenated, analysis = helper.analyze_body(body, True)
assert len(raw) == 3 and len(events) == 3
assert analysis["intermediate_event_count"] == 2
assert analysis["terminal_event_present"] is True
assert analysis["terminal_done_reason"] == "stop"
assert concatenated == b"first second"

with tempfile.TemporaryDirectory() as temporary:
    destination = Path(temporary) / "capture"
    helper.initialize_capture(destination, true_request)
    helper.persist_http_capture(
        destination, body, http, raw, events, concatenated, analysis,
    )
    assert (destination / "http-body.bin").read_bytes() == stream_body
    assert (destination / "events/0001.raw").read_bytes() == raw[0]
    assert (destination / "concatenated-response.txt").read_bytes() == concatenated
    assert json.loads((destination / "analysis.json").read_text())["event_count"] == 3

print("ollama-http-forensics: PASS")
