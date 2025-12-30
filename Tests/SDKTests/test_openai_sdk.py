#!/usr/bin/env python3
"""
OpenAI SDK Integration Tests

Tests OpenAI Python SDK compatibility with AFMBridge server.

Requirements:
    pip install openai

Usage:
    # Start AFMBridge server first
    python test_openai_sdk.py

Environment:
    AFMBRIDGE_URL: Server URL (default: http://localhost:8080)
"""

import os
import sys
from openai import OpenAI


def test_non_streaming_chat():
    """Test non-streaming chat completion."""
    base_url = os.getenv("AFMBRIDGE_URL", "http://localhost:8080")
    client = OpenAI(
        base_url=f"{base_url}/v1",
        api_key="not-needed"  # AFM doesn't require API key
    )

    print("Testing non-streaming chat completion...")
    try:
        response = client.chat.completions.create(
            model="gpt-4o",  # Model identifier (AFM ignores this)
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": "Say 'Hello from OpenAI SDK!'"}
            ],
            max_tokens=100
        )

        assert response.object == "chat.completion"
        assert len(response.choices) == 1
        assert response.choices[0].message.role == "assistant"
        assert len(response.choices[0].message.content) > 0
        assert response.choices[0].finish_reason == "stop"

        print(f"✓ Non-streaming response: {response.choices[0].message.content[:50]}...")
        return True

    except Exception as e:
        print(f"✗ Non-streaming test failed: {e}")
        return False


def test_streaming_chat():
    """Test streaming chat completion."""
    base_url = os.getenv("AFMBRIDGE_URL", "http://localhost:8080")
    client = OpenAI(
        base_url=f"{base_url}/v1",
        api_key="not-needed"
    )

    print("Testing streaming chat completion...")
    try:
        stream = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "user", "content": "Count from 1 to 5."}
            ],
            stream=True,
            max_tokens=100
        )

        chunks = []
        for chunk in stream:
            if chunk.choices and chunk.choices[0].delta.content:
                chunks.append(chunk.choices[0].delta.content)

        full_response = "".join(chunks)
        assert len(full_response) > 0, "Stream produced no content"

        print(f"✓ Streaming response ({len(chunks)} chunks): {full_response[:50]}...")
        return True

    except Exception as e:
        print(f"✗ Streaming test failed: {e}")
        print("Note: Streaming requires Phase 2 implementation")
        return False


def main():
    """Run all OpenAI SDK integration tests."""
    print("=" * 60)
    print("OpenAI SDK Integration Tests")
    print("=" * 60)

    # Streaming is expected to fail until Phase 2 implementation
    EXPECTED_FAILURES = {"Streaming chat"}

    results = {
        "Non-streaming chat": test_non_streaming_chat(),
        "Streaming chat": test_streaming_chat()
    }

    print("\n" + "=" * 60)
    print("Summary:")
    for test_name, passed in results.items():
        if test_name in EXPECTED_FAILURES and not passed:
            print(f"  {test_name}: XFAIL (expected)")
        else:
            status = "PASS" if passed else "FAIL"
            print(f"  {test_name}: {status}")

    # Only fail if unexpected failures occur
    unexpected_failures = [
        name for name, passed in results.items()
        if not passed and name not in EXPECTED_FAILURES
    ]
    exit_code = 1 if unexpected_failures else 0

    print(f"\nOverall: {'PASS' if exit_code == 0 else 'FAIL'}")
    print("=" * 60)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
