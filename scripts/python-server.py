#!/usr/bin/env python3
"""
Green Python Lab - Servidor de teste em Python compatível com workloads k6.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

MAX_SCALE = 5


def is_prime(number: int) -> bool:
    if number < 2:
        return False
    if number == 2:
        return True
    if number % 2 == 0:
        return False
    limit = int(math.floor(math.isqrt(number)))
    for divisor in range(3, limit + 1, 2):
        if number % divisor == 0:
            return False
    return True


def calculate_prime_checksum(limit: int) -> dict[str, int]:
    total_sum = 0
    count = 0
    for number in range(2, limit + 1):
        if is_prime(number):
            total_sum += number
            count += 1
    return {"count": count, "checksum": total_sum}


def build_text_corpus(paragraphs: int) -> list[str]:
    base = [
        "Green software reduces unnecessary computation and resource usage.",
        "Repeatable workloads make performance and energy comparisons fair.",
        "A profiler helps developers locate expensive functions in the code.",
        "Energy measurements should be interpreted together with latency and throughput.",
        "Optimizing an algorithm can reduce execution time and operational emissions.",
    ]
    return [base[i % len(base)] + f" Sample={i}" for i in range(paragraphs)]


def normalize_sentence(sentence: str) -> list[str]:
    normalized = re.sub(r"[^a-z0-9\s=]", " ", sentence.lower())
    return [w for w in normalized.strip().split() if w]


def count_words(corpus: list[str]) -> dict[str, int]:
    frequencies: dict[str, int] = {}
    for sentence in corpus:
        for word in normalize_sentence(sentence):
            frequencies[word] = frequencies.get(word, 0) + 1
    return dict(sorted(frequencies.items()))


def text_checksum(frequencies: dict[str, int]) -> str:
    encoded = json.dumps(frequencies, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def execute_cpu_workload(scale: int) -> dict[str, object]:
    limit = 2500 * scale
    res = calculate_prime_checksum(limit)
    return {
        "limit": limit,
        "prime_count": res["count"],
        "checksum": str(res["checksum"]),
    }


def execute_text_workload(scale: int) -> dict[str, object]:
    paragraphs = 300 * scale
    corpus = build_text_corpus(paragraphs)
    frequencies = count_words(corpus)
    return {
        "paragraphs": paragraphs,
        "unique_words": len(frequencies),
        "checksum": text_checksum(frequencies),
    }


def wp_load_all_options(count: int) -> dict[str, str]:
    return {f"wp_option_autoload_{i}": f"wp_setting_{i}" for i in range(count)}


def wp_query_get_posts(posts_count: int) -> list[dict[str, object]]:
    posts = []
    for i in range(posts_count):
        meta_hash = hashlib.sha256(f"post_meta_{i}_0".encode()).hexdigest()
        posts.append({
            "id": i,
            "title": f"WordPress Post Title {i}",
            "content": f"<!-- wp:paragraph --><p>Welcome to WordPress post {i} with [custom_shortcode id={i}]</p><!-- /wp:paragraph -->",
            "meta": {"key_0": meta_hash},
        })
    return posts


def wp_apply_filters(tag: str, value: str, iterations: int) -> str:
    rendered = value.replace("[custom_shortcode id=", "<strong>Shortcode Rendered ")
    rendered = rendered.replace("]", "</strong>")
    return rendered.strip().lower()


def execute_wordpress_workload(scale: int) -> dict[str, object]:
    options_count = 100 * scale
    posts_count = 15 * scale
    filter_iterations = 200 * scale

    options = wp_load_all_options(options_count)
    posts = wp_query_get_posts(posts_count)
    rendered_content = "".join(
        wp_apply_filters("the_content", str(p["content"]), filter_iterations)
        for p in posts
    )
    raw = f"{len(options)}{len(posts)}{len(rendered_content)}"
    checksum = hashlib.sha256(raw.encode()).hexdigest()
    return {
        "options_loaded": len(options),
        "posts_queried": len(posts),
        "rendered_length": len(rendered_content),
        "checksum": checksum,
    }


def execute_mixed_workload(scale: int) -> dict[str, object]:
    cpu = execute_cpu_workload(scale)
    text = execute_text_workload(scale)
    combined = f"{cpu['checksum']}{text['checksum']}"
    return {
        "cpu": cpu,
        "text": text,
        "checksum": hashlib.sha256(combined.encode()).hexdigest(),
    }


class RequestHandler(BaseHTTPRequestHandler):
    def _send_json(self, data: object, status: int = 200) -> None:
        payload = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == "/health":
            self._send_json({
                "application": "Green Python Lab",
                "status": "ok",
                "python_version": "3",
            })
            return

        if path == "/work":
            workload = query.get("workload", ["wordpress"])[0]
            try:
                scale = max(1, min(int(query.get("scale", ["1"])[0]), MAX_SCALE))
            except ValueError:
                scale = 1

            if workload == "cpu":
                res = execute_cpu_workload(scale)
            elif workload == "text":
                res = execute_text_workload(scale)
            elif workload == "wordpress":
                res = execute_wordpress_workload(scale)
            elif workload == "mixed":
                res = execute_mixed_workload(scale)
            else:
                self._send_json({"error": f"Unknown workload: {workload}"}, 400)
                return

            self._send_json({"workload": workload, "scale": scale, "result": res})
            return

        # Default fallback
        self._send_json({
            "application": "Green Python Lab",
            "status": "running",
            "endpoints": ["/health", "/work?workload=<cpu|text|wordpress|mixed>&scale=<1..5>"],
        })

    def log_message(self, format: str, *args: object) -> None:
        # Silencia logs barulhentos no stderr para nao poluir terminal
        pass


class ReusableHTTPServer(HTTPServer):
    allow_reuse_address = True


def main() -> None:
    parser = argparse.ArgumentParser(description="Green Python Lab Test Server")
    parser.add_argument("--host", default="127.0.0.1", help="Host binding (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8080, help="Port binding (default: 8080)")
    args = parser.parse_args()

    server_address = (args.host, args.port)
    httpd = ReusableHTTPServer(server_address, RequestHandler)
    print(f"Starting Green Python Lab at http://{args.host}:{args.port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
