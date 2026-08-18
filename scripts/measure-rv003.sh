#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_root=${0:A:h:h}
sample_count=${1:-30}
app_path="$project_root/artifacts/Marla_dev.app/Contents/MacOS/Marla"

if [[ ! "$sample_count" =~ '^[1-9][0-9]*$' ]]; then
    echo "Sample count must be a positive integer." >&2
    exit 2
fi
if [[ ! -x "$app_path" ]]; then
    echo "Missing executable fixed App: $app_path" >&2
    exit 2
fi

run_directory=$(mktemp -d /private/tmp/marla-rv003.XXXXXX)
server_pid=""
cleanup() {
    if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$run_directory"
}
trap cleanup EXIT INT TERM

report_path="$run_directory/latency.jsonl"
server_url_path="$run_directory/server-url.txt"
isolated_home="$run_directory/home"
mkdir -p "$isolated_home"

cargo build --quiet --manifest-path "$project_root/Cargo.toml" \
    -p marla-core --example performance_sse_server
"$project_root/target/debug/examples/performance_sse_server" \
    "$sample_count" "$server_url_path" &
server_pid=$!

for _ in {1..200}; do
    [[ -s "$server_url_path" ]] && break
    sleep 0.01
done
if [[ ! -s "$server_url_path" ]]; then
    echo "Local SSE server did not become ready." >&2
    exit 1
fi
server_url=$(<"$server_url_path")

for index in $(seq 1 "$sample_count"); do
    CFFIXED_USER_HOME="$isolated_home" \
    MARLA_UI_TEST_SCENARIO=performance-shell \
    MARLA_PERFORMANCE_REPORT_PATH="$report_path" \
    MARLA_PERFORMANCE_EXIT_AFTER_SAMPLE=1 \
        "$app_path"

    CFFIXED_USER_HOME="$isolated_home" \
    MARLA_UI_TEST_SCENARIO=performance-rust-delta \
    MARLA_PERFORMANCE_BASE_URL="$server_url" \
    MARLA_PERFORMANCE_REPORT_PATH="$report_path" \
    MARLA_PERFORMANCE_EXIT_AFTER_SAMPLE=1 \
        "$app_path"

    echo "Completed sample pair $index/$sample_count" >&2
done

wait "$server_pid"
server_pid=""

summarize_metric() {
    local metric=$1
    local values_path="$run_directory/$metric.txt"
    jq -r --arg metric "$metric" \
        'select(.metric == $metric) | .durationNanoseconds' \
        "$report_path" | sort -n > "$values_path"
    local count
    count=$(wc -l < "$values_path" | tr -d ' ')
    if [[ "$count" -ne "$sample_count" ]]; then
        echo "Expected $sample_count $metric samples, found $count." >&2
        exit 1
    fi
    awk -v metric="$metric" '
        { values[NR] = $1 }
        END {
            p50 = int((NR * 0.50) + 0.999999)
            p95 = int((NR * 0.95) + 0.999999)
            printf "%s count=%d p50=%.3fms p95=%.3fms max=%.3fms\n", \
                metric, NR, values[p50] / 1000000, values[p95] / 1000000, values[NR] / 1000000
        }
    ' "$values_path"
}

summarize_metric local_entry_to_visible_shell
summarize_metric rust_callback_to_swift_visible_delta

evidence_path=${MARLA_RV003_EVIDENCE_PATH:-/private/tmp/marla-rv003-latency.jsonl}
cp "$report_path" "$evidence_path"
echo "Raw latency evidence: $evidence_path"
