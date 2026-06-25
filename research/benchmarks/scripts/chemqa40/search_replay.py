#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import statistics
import sys
import time
import urllib.error
import urllib.request
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class QueryItem:
    qa_id: str
    paper_id: str
    topic: str
    query_slot: str
    query_text: str


def api_json(method: str, url: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def ensure_project(api_base: str, title: str, corpus_key: str) -> str:
    projects = api_json("GET", f"{api_base}/projects").get("projects", [])
    for project in projects:
        if project.get("title") == title:
            project_id = project["project_id"]
            api_json(
                "PATCH",
                f"{api_base}/projects/{project_id}",
                {"selected_corpora": [corpus_key]},
            )
            return project_id
    created = api_json("POST", f"{api_base}/projects", {"title": title})
    project_id = created["project_id"]
    api_json(
        "PATCH",
        f"{api_base}/projects/{project_id}",
        {"selected_corpora": [corpus_key]},
    )
    return project_id


def load_queries(annotation_path: Path, mode: str, samples_per_topic: int) -> list[QueryItem]:
    rows = [json.loads(line) for line in annotation_path.open()]
    query_items: list[QueryItem] = []
    for row in rows:
        if row.get("search_query_status") != "done":
            continue
        for slot in ("search_query_1", "search_query_2"):
            text = row.get(slot)
            if text:
                query_items.append(
                    QueryItem(
                        qa_id=row["qa_id"],
                        paper_id=row["paper_id"],
                        topic=row["topic"],
                        query_slot=slot,
                        query_text=text,
                    )
                )
    if mode == "full":
        return query_items

    per_topic: dict[str, list[QueryItem]] = defaultdict(list)
    for item in query_items:
        if len(per_topic[item.topic]) < samples_per_topic:
            per_topic[item.topic].append(item)

    selected: list[QueryItem] = []
    for topic in sorted(per_topic):
        selected.extend(per_topic[topic])
    return selected


def poll_job(api_base: str, job_id: str, poll_interval: float, timeout_seconds: float) -> dict[str, Any]:
    deadline = time.time() + timeout_seconds
    while True:
        status = api_json("GET", f"{api_base}/search/jobs/{job_id}")
        if status["status"] in {"completed", "failed"}:
            return status
        if time.time() > deadline:
            raise TimeoutError(f"job {job_id} timed out after {timeout_seconds}s")
        time.sleep(poll_interval)


def find_bucket(result: dict[str, Any], paper_id: str) -> tuple[str, dict[str, Any] | None]:
    for bucket_name in ("satisfied", "partial", "rejected"):
        for item in result.get(bucket_name, []):
            if item.get("paper_id") == paper_id:
                return bucket_name, item
    return "not_returned", None


def compute_metrics(records: list[dict[str, Any]]) -> dict[str, Any]:
    completed = [r for r in records if r["job_status"] == "completed"]
    failed = [r for r in records if r["job_status"] != "completed"]
    if completed:
        hit1 = sum(r["target_hit_at_1"] for r in completed) / len(completed)
        hit3 = sum(r["target_hit_at_3"] for r in completed) / len(completed)
        hit5 = sum(r["target_hit_at_5"] for r in completed) / len(completed)
        hit10 = sum(r["target_hit_at_10"] for r in completed) / len(completed)
        mrr = sum(r["mrr"] for r in completed) / len(completed)
        satisfied = sum(r["target_bucket"] == "satisfied" for r in completed) / len(completed)
        partial_or_better = sum(r["target_bucket"] in {"satisfied", "partial"} for r in completed) / len(completed)
        avg_latency = statistics.mean(r["total_latency_sec"] for r in completed if r["total_latency_sec"] is not None)
    else:
        hit1 = hit3 = hit5 = hit10 = mrr = satisfied = partial_or_better = avg_latency = 0.0

    by_topic: dict[str, dict[str, Any]] = {}
    topic_groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in completed:
        topic_groups[record["topic"]].append(record)
    for topic, group in sorted(topic_groups.items()):
        by_topic[topic] = {
            "count": len(group),
            "hit_at_1": sum(r["target_hit_at_1"] for r in group) / len(group),
            "hit_at_3": sum(r["target_hit_at_3"] for r in group) / len(group),
            "hit_at_5": sum(r["target_hit_at_5"] for r in group) / len(group),
            "mrr": sum(r["mrr"] for r in group) / len(group),
            "target_in_satisfied": sum(r["target_bucket"] == "satisfied" for r in group) / len(group),
        }

    return {
        "query_count": len(records),
        "completed_count": len(completed),
        "failed_count": len(failed),
        "hit_at_1": hit1,
        "hit_at_3": hit3,
        "hit_at_5": hit5,
        "hit_at_10": hit10,
        "mrr": mrr,
        "target_in_satisfied": satisfied,
        "target_in_partial_or_better": partial_or_better,
        "avg_latency_sec": avg_latency,
        "by_topic": by_topic,
    }


def write_summary_md(path: Path, summary: dict[str, Any], run_name: str, corpus_key: str) -> None:
    lines = [
        f"# ChemQA40 Search Replay Summary: {run_name}",
        "",
        f"- corpus: `{corpus_key}`",
        f"- query_count: `{summary['query_count']}`",
        f"- completed_count: `{summary['completed_count']}`",
        f"- failed_count: `{summary['failed_count']}`",
        f"- Hit@1: `{summary['hit_at_1']:.3f}`",
        f"- Hit@3: `{summary['hit_at_3']:.3f}`",
        f"- Hit@5: `{summary['hit_at_5']:.3f}`",
        f"- Hit@10: `{summary['hit_at_10']:.3f}`",
        f"- MRR: `{summary['mrr']:.3f}`",
        f"- target_in_satisfied: `{summary['target_in_satisfied']:.3f}`",
        f"- target_in_partial_or_better: `{summary['target_in_partial_or_better']:.3f}`",
        f"- avg_latency_sec: `{summary['avg_latency_sec']:.2f}`",
        "",
        "## By Topic",
        "",
    ]
    for topic, metrics in summary["by_topic"].items():
        lines.extend(
            [
                f"### {topic}",
                f"- count: `{metrics['count']}`",
                f"- Hit@1: `{metrics['hit_at_1']:.3f}`",
                f"- Hit@3: `{metrics['hit_at_3']:.3f}`",
                f"- Hit@5: `{metrics['hit_at_5']:.3f}`",
                f"- MRR: `{metrics['mrr']:.3f}`",
                f"- target_in_satisfied: `{metrics['target_in_satisfied']:.3f}`",
                "",
            ]
        )
    path.write_text("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-base", default="http://127.0.0.1:4001/api")
    parser.add_argument("--annotation-file", required=True)
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--mode", choices=["smoke", "full"], default="smoke")
    parser.add_argument("--samples-per-topic", type=int, default=4)
    parser.add_argument("--project-title", default="ChemQA40 Smoke Replay")
    parser.add_argument("--corpus-key", default="chemqa40/2026/all")
    parser.add_argument("--top-k", type=int, default=10)
    parser.add_argument("--display-k", type=int, default=10)
    parser.add_argument("--poll-interval", type=float, default=2.0)
    parser.add_argument("--timeout-seconds", type=float, default=900.0)
    args = parser.parse_args()

    annotation_path = Path(args.annotation_file)
    run_dir = Path(args.run_dir)
    logs_dir = run_dir / "logs"
    run_dir.mkdir(parents=True, exist_ok=True)
    logs_dir.mkdir(parents=True, exist_ok=True)

    queries = load_queries(annotation_path, args.mode, args.samples_per_topic)
    project_id = ensure_project(args.api_base, args.project_title, args.corpus_key)

    run_config = {
        "api_base": args.api_base,
        "annotation_file": str(annotation_path),
        "mode": args.mode,
        "samples_per_topic": args.samples_per_topic,
        "project_title": args.project_title,
        "project_id": project_id,
        "corpus_key": args.corpus_key,
        "top_k": args.top_k,
        "display_k": args.display_k,
        "query_count": len(queries),
    }
    (run_dir / "run_config.json").write_text(json.dumps(run_config, indent=2, ensure_ascii=False))

    raw_results_path = run_dir / "raw_results.jsonl"
    records: list[dict[str, Any]] = []
    with raw_results_path.open("w") as raw_file:
        for index, item in enumerate(queries, start=1):
            print(f"[{index}/{len(queries)}] {item.qa_id} {item.query_slot} :: {item.query_text}", flush=True)
            try:
                status = api_json(
                    "POST",
                    f"{args.api_base}/search/jobs",
                    {
                        "project_id": project_id,
                        "query": item.query_text,
                        "top_k": args.top_k,
                        "display_k": args.display_k,
                    },
                )
                final_status = poll_job(
                    args.api_base,
                    status["job_id"],
                    args.poll_interval,
                    args.timeout_seconds,
                )
                record: dict[str, Any] = {
                    "qa_id": item.qa_id,
                    "paper_id": item.paper_id,
                    "topic": item.topic,
                    "query_slot": item.query_slot,
                    "query_text": item.query_text,
                    "job_id": status["job_id"],
                    "job_status": final_status["status"],
                    "trace_id": final_status.get("trace_id"),
                    "total_latency_sec": round(final_status.get("elapsed_ms", 0.0) / 1000.0, 3),
                }
                if final_status["status"] == "completed":
                    result = api_json("GET", f"{args.api_base}/search/jobs/{status['job_id']}/result")
                    display_ids = [x["paper_id"] for x in result.get("display_results", [])]
                    bucket, matched = find_bucket(result, item.paper_id)
                    target_rank = display_ids.index(item.paper_id) + 1 if item.paper_id in display_ids else None
                    record.update(
                        {
                            "target_rank": target_rank,
                            "target_hit_at_1": int(target_rank == 1) if target_rank else 0,
                            "target_hit_at_3": int(target_rank is not None and target_rank <= 3),
                            "target_hit_at_5": int(target_rank is not None and target_rank <= 5),
                            "target_hit_at_10": int(target_rank is not None and target_rank <= 10),
                            "mrr": (1.0 / target_rank) if target_rank else 0.0,
                            "target_bucket": bucket,
                            "target_verdict": matched.get("verdict") if matched else None,
                            "top10_paper_ids": display_ids[:10],
                            "counts": result.get("counts", {}),
                        }
                    )
                    trace_id = result.get("trace_id")
                    if trace_id:
                        try:
                            trace = api_json("GET", f"{args.api_base}/traces/{trace_id}")
                            record["trace_timings_ms"] = trace.get("timings_ms", {})
                        except Exception as exc:  # noqa: BLE001
                            record["trace_error"] = str(exc)
                else:
                    record.update(
                        {
                            "target_rank": None,
                            "target_hit_at_1": 0,
                            "target_hit_at_3": 0,
                            "target_hit_at_5": 0,
                            "target_hit_at_10": 0,
                            "mrr": 0.0,
                            "target_bucket": "not_returned",
                            "target_verdict": None,
                            "top10_paper_ids": [],
                            "error": final_status.get("error"),
                        }
                    )
            except Exception as exc:  # noqa: BLE001
                record = {
                    "qa_id": item.qa_id,
                    "paper_id": item.paper_id,
                    "topic": item.topic,
                    "query_slot": item.query_slot,
                    "query_text": item.query_text,
                    "job_status": "client_error",
                    "target_rank": None,
                    "target_hit_at_1": 0,
                    "target_hit_at_3": 0,
                    "target_hit_at_5": 0,
                    "target_hit_at_10": 0,
                    "mrr": 0.0,
                    "target_bucket": "not_returned",
                    "target_verdict": None,
                    "top10_paper_ids": [],
                    "error": str(exc),
                }
            raw_file.write(json.dumps(record, ensure_ascii=False) + "\n")
            raw_file.flush()
            records.append(record)

    summary = compute_metrics(records)
    (run_dir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False))
    write_summary_md(run_dir / "summary.md", summary, run_dir.name, args.corpus_key)
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
