#!/usr/bin/env python3
"""Apply and verify one migration through the hosted Supabase MCP server."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


PROTOCOL_VERSION = "2025-06-18"


class MCPClient:
    def __init__(self, endpoint: str, access_token: str) -> None:
        self.endpoint = endpoint
        self.access_token = access_token
        self.session_id: str | None = None
        self.request_id = 0

    def _post(self, payload: dict[str, Any], expect_response: bool = True) -> Any:
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            # Cloudflare rejects Python urllib's default user-agent before the
            # request reaches Supabase. Use an explicit MCP client identity.
            "User-Agent": "spot-mcp-deployer/1.0",
        }
        if self.session_id:
            headers["Mcp-Session-Id"] = self.session_id

        request = urllib.request.Request(
            self.endpoint,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                if session_id := response.headers.get("Mcp-Session-Id"):
                    self.session_id = session_id
                body = response.read().decode("utf-8")
                content_type = response.headers.get_content_type()
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"MCP HTTP {error.code}: {body or error.reason}"
            ) from error

        if not expect_response or not body:
            return None

        if content_type == "text/event-stream":
            messages = [
                json.loads(line.removeprefix("data:").strip())
                for line in body.splitlines()
                if line.startswith("data:") and line.removeprefix("data:").strip()
            ]
            if not messages:
                raise RuntimeError("MCP returned an empty event stream")
            message = messages[-1]
        else:
            message = json.loads(body)

        if "error" in message:
            raise RuntimeError(f"MCP error: {json.dumps(message['error'])}")
        return message.get("result")

    def initialize(self) -> None:
        self.request_id += 1
        self._post(
            {
                "jsonrpc": "2.0",
                "id": self.request_id,
                "method": "initialize",
                "params": {
                    "protocolVersion": PROTOCOL_VERSION,
                    "capabilities": {},
                    "clientInfo": {
                        "name": "spot-github-actions",
                        "version": "1.0",
                    },
                },
            }
        )
        self._post(
            {
                "jsonrpc": "2.0",
                "method": "notifications/initialized",
                "params": {},
            },
            expect_response=False,
        )

    def call_tool(self, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        self.request_id += 1
        result = self._post(
            {
                "jsonrpc": "2.0",
                "id": self.request_id,
                "method": "tools/call",
                "params": {"name": name, "arguments": arguments},
            }
        )
        if not isinstance(result, dict):
            raise RuntimeError(f"Unexpected {name} response: {result!r}")
        if result.get("isError"):
            raise RuntimeError(f"{name} failed: {json.dumps(result.get('content'))}")
        return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--migration", type=Path, required=True)
    parser.add_argument("--name", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    access_token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not access_token:
        print("SUPABASE_ACCESS_TOKEN is not configured", file=sys.stderr)
        return 2

    sql = args.migration.read_text(encoding="utf-8")
    client = MCPClient(args.endpoint, access_token)
    client.initialize()

    common = {"project_id": args.project_id}
    client.call_tool(
        "apply_migration",
        {**common, "name": args.name, "query": sql},
    )

    verification_sql = """
select
  to_regprocedure('public.is_username_available(text)') is not null as rpc_exists,
  to_regclass('public.users_username_normalized_uidx') is not null as index_exists,
  has_function_privilege(
    'anon',
    'public.is_username_available(text)',
    'execute'
  ) as anon_can_execute,
  public.is_username_available('a_valid_user') in (true, false)
    as rpc_returns_boolean;
""".strip()
    verification = client.call_tool(
        "execute_sql",
        {**common, "query": verification_sql},
    )
    content_text = "\n".join(
        item.get("text", "")
        for item in verification.get("content", [])
        if isinstance(item, dict)
    )
    verification_text = content_text + json.dumps(
        verification.get("structuredContent", {})
    )
    required_markers = (
        '"rpc_exists":true',
        '"index_exists":true',
        '"anon_can_execute":true',
        '"rpc_returns_boolean":true',
    )
    compact_result = verification_text.replace(" ", "")
    missing = [marker for marker in required_markers if marker not in compact_result]
    if missing:
        raise RuntimeError(
            "Migration verification failed; missing true markers: "
            + ", ".join(missing)
            + f". Response: {verification_text}"
        )

    print("Supabase MCP migration and verification succeeded.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
