#!/usr/bin/env python3
"""List open GitLab merge requests authored by the authenticated user."""

from __future__ import annotations

import json
import subprocess
import sys
from typing import Iterable


STATUS_LABELS = {
    "success": "OK",
    "failed": "FAIL",
    "running": "RUN",
    "pending": "RUN",
    "created": "RUN",
    "canceled": "SKIP",
    "skipped": "SKIP",
}

STATUS_ICONS = {
    "success": "✅",
    "failed": "❌",
    "running": "🏃",
    "pending": "⏳",
    "created": "⏳",
    "canceled": "⏭️",
    "skipped": "⏭️",
    "unknown": "❔",
}


def run_cmd(args: Iterable[str]) -> str:
    result = subprocess.run(list(args), capture_output=True, text=True)
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(message or "Command failed")
    return result.stdout


def try_cmd(args: Iterable[str]) -> str | None:
    result = subprocess.run(list(args), capture_output=True, text=True)
    if result.returncode != 0:
        return None
    return result.stdout


def parse_repo_path(item: dict) -> str:
    refs = item.get("references") or {}
    full = refs.get("full") or ""
    if "!" in full:
        return full.split("!")[0]

    web_url = item.get("web_url", "")
    if "https://gitlab.com/" in web_url:
        return web_url.split("https://gitlab.com/")[-1].split("/-/merge_requests/")[0]

    return ""


def pipeline_status(iid: int, repo_path: str) -> str:
    args = ["glab", "mr", "view", str(iid), "--output", "json"]
    if repo_path:
        args.extend(["--repo", repo_path])

    output = try_cmd(args)
    if not output:
        return "unknown"

    try:
        data = json.loads(output)
    except json.JSONDecodeError:
        return "unknown"

    pipeline = data.get("head_pipeline") or data.get("pipeline") or {}
    return pipeline.get("status", "unknown")


def main() -> int:
    args = sys.argv[1:]
    json_output = False
    if "--json" in args:
        json_output = True
        args = [arg for arg in args if arg != "--json"]

    list_args = [
        "glab",
        "mr",
        "list",
        "--author",
        "@me",
        "--order",
        "updated_at",
        "--sort",
        "desc",
        "--output",
        "json",
    ]
    list_args.extend(args)

    try:
        output = run_cmd(list_args)
    except RuntimeError as exc:
        print(f"Error: glab mr list failed: {exc}", file=sys.stderr)
        return 1

    if not output.strip() or output.strip() == "[]":
        if json_output:
            print("[]")
        else:
            print("No open merge requests found.")
        return 0

    try:
        items = json.loads(output)
    except json.JSONDecodeError as exc:
        print(f"Error: failed to parse glab output: {exc}", file=sys.stderr)
        return 1

    results: list[dict] = []
    for item in items:
        iid = item.get("iid")
        if iid is None:
            continue

        refs = item.get("references") or {}
        short = refs.get("short") or f"!{iid}"
        title = (item.get("title") or "").replace("\t", " ").replace("\n", " ")
        web_url = item.get("web_url", "")
        repo_path = parse_repo_path(item)

        status = pipeline_status(iid, repo_path)
        label = STATUS_LABELS.get(status, "?")

        results.append(
            {
                "iid": iid,
                "short": short,
                "title": title,
                "web_url": web_url,
                "repo_path": repo_path,
                "pipeline_status": status,
                "status_label": label,
            }
        )

    if json_output:
        print(json.dumps(results, indent=2))
        return 0

    print(f"{'Status':<9} {'MR':<8} Title")
    print(f"{'---------':<9} {'--':<8} -----")

    for result in results:
        icon = STATUS_ICONS.get(result["pipeline_status"], STATUS_ICONS["unknown"])
        display_status = f"{icon} {result['status_label']}"
        print(
            f"{display_status:<9} {result['short']:<8} "
            f"{result['title']} ({result['web_url']})"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
