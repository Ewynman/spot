#!/usr/bin/env python3
"""Apply and verify one migration through the hosted Supabase MCP server."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
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

    def call_tool(
        self,
        name: str,
        arguments: dict[str, Any],
        retries: int = 0,
    ) -> dict[str, Any]:
        for attempt in range(retries + 1):
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
            if not result.get("isError"):
                return result

            error_text = json.dumps(result.get("content"))
            retryable = any(
                marker in error_text.lower()
                for marker in ("connection timeout", "temporarily unavailable")
            )
            if not retryable or attempt == retries:
                raise RuntimeError(f"{name} failed: {error_text}")
            time.sleep(3 * (attempt + 1))

        raise RuntimeError(f"{name} exhausted retries")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--project-id")
    parser.add_argument("--migration", type=Path, required=True)
    parser.add_argument("--name", required=True)
    return parser.parse_args()


def response_text(value: Any) -> str:
    if isinstance(value, str):
        parts = [value]
        stripped = value.strip()
        if stripped.startswith(("{", "[")):
            try:
                decoded = json.loads(stripped)
            except json.JSONDecodeError:
                pass
            else:
                parts.append(response_text(decoded))
        return "\n".join(parts)
    if isinstance(value, dict):
        return json.dumps(value, separators=(",", ":")) + "\n" + "\n".join(
            response_text(item) for item in value.values()
        )
    if isinstance(value, list):
        return json.dumps(value, separators=(",", ":")) + "\n" + "\n".join(
            response_text(item) for item in value
        )
    return ""


def verify_migration(client: MCPClient) -> tuple[bool, str]:
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
        {"query": verification_sql},
        retries=2,
    )
    compact_result = response_text(verification).replace(" ", "")
    required_markers = (
        '"rpc_exists":true',
        '"index_exists":true',
        '"anon_can_execute":true',
        '"rpc_returns_boolean":true',
    )
    return all(marker in compact_result for marker in required_markers), compact_result


def verify_unique_precondition(client: MCPClient) -> None:
    preflight_sql = """
select not exists (
  select 1
  from public.users
  where username is not null
  group by lower(btrim(username))
  having count(*) > 1
) as no_duplicate_usernames;
""".strip()
    preflight = client.call_tool(
        "execute_sql",
        {"query": preflight_sql},
        retries=2,
    )
    compact_result = response_text(preflight).replace(" ", "")
    if '"no_duplicate_usernames":true' not in compact_result:
        raise RuntimeError(
            "Migration blocked: duplicate normalized usernames exist. "
            "No production DDL was applied."
        )


def ensure_project_active(access_token: str, project_id: str) -> None:
    client = MCPClient(
        "https://mcp.supabase.com/mcp?features=account",
        access_token,
    )
    client.initialize()

    def project_status() -> str:
        project = client.call_tool("get_project", {"id": project_id})
        compact = response_text(project).replace(" ", "")
        for status in (
            "ACTIVE_HEALTHY",
            "COMING_UP",
            "INACTIVE",
            "PAUSED",
            "ACTIVE_UNHEALTHY",
        ):
            if f'"status":"{status}"' in compact:
                return status
        return "UNKNOWN"

    status = project_status()
    if status in ("INACTIVE", "PAUSED"):
        print("Production project is paused; requesting restore through MCP.")
        client.call_tool("restore_project", {"project_id": project_id})
        status = "COMING_UP"

    if status == "ACTIVE_HEALTHY":
        return

    for _ in range(20):
        time.sleep(15)
        status = project_status()
        if status == "ACTIVE_HEALTHY":
            print("Production project is active and healthy.")
            return

    raise RuntimeError(
        f"Project did not become ACTIVE_HEALTHY; current status: {status}"
    )


def main() -> int:
    args = parse_args()
    access_token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not access_token:
        print("SUPABASE_ACCESS_TOKEN is not configured", file=sys.stderr)
        return 2

    if args.project_id:
        ensure_project_active(access_token, args.project_id)

    sql = args.migration.read_text(encoding="utf-8")
    client = MCPClient(args.endpoint, access_token)
    client.initialize()

    verified, _ = verify_migration(client)
    if verified:
        print("Supabase migration was already applied and verification succeeded.")
        return 0

    verify_unique_precondition(client)
    client.call_tool(
        "apply_migration",
        {"name": args.name, "query": sql},
    )

    verified, verification_text = verify_migration(client)
    if not verified:
        raise RuntimeError(f"Migration verification failed: {verification_text}")

    print("Supabase MCP migration and verification succeeded.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
