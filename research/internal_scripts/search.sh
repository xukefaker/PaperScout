#!/usr/bin/env zsh

emulate -L zsh
setopt errexit nounset pipefail

# ----------------------------
# Search request
# ----------------------------
QUERY="${QUERY:-Find ACL 2025 papers that evaluate on the MATH benchmark.}"
TOP_K="${TOP_K:-10}"

# ----------------------------
# Output behavior
# ----------------------------
SAVE_OUTPUT="${SAVE_OUTPUT:-1}"
PRINT_SUMMARY="${PRINT_SUMMARY:-1}"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-search_run}"
OUTPUT_DIR="${OUTPUT_DIR:-}"
OUTPUT_FILE="${OUTPUT_FILE:-}"

# ----------------------------
# Runtime overrides
# Leave empty to use config.toml / .env defaults.
# ----------------------------
LOG_LEVEL="${LOG_LEVEL:-INFO}"
DATA_DIR_OVERRIDE="${DATA_DIR_OVERRIDE:-}"
OPENAI_BASE_URL_OVERRIDE="${OPENAI_BASE_URL_OVERRIDE:-}"
OPENAI_MODEL_OVERRIDE="${OPENAI_MODEL_OVERRIDE:-}"
REQUEST_TIMEOUT_OVERRIDE="${REQUEST_TIMEOUT_OVERRIDE:-}"
PAPER_DENSE_MODEL_OVERRIDE="${PAPER_DENSE_MODEL_OVERRIDE:-}"
CHUNK_DENSE_MODEL_OVERRIDE="${CHUNK_DENSE_MODEL_OVERRIDE:-}"
DENSE_DEVICE_OVERRIDE="${DENSE_DEVICE_OVERRIDE:-}"
DENSE_BATCH_SIZE_OVERRIDE="${DENSE_BATCH_SIZE_OVERRIDE:-}"
RERANKER_ENABLED_OVERRIDE="${RERANKER_ENABLED_OVERRIDE:-}"
RERANKER_MODEL_OVERRIDE="${RERANKER_MODEL_OVERRIDE:-}"
RERANKER_DEVICE_OVERRIDE="${RERANKER_DEVICE_OVERRIDE:-}"
RERANKER_BATCH_SIZE_OVERRIDE="${RERANKER_BATCH_SIZE_OVERRIDE:-}"

# ----------------------------
# Retrieval overrides
# Leave empty to use config.toml values.
# ----------------------------
CANDIDATE_POOL_SIZE_OVERRIDE="${CANDIDATE_POOL_SIZE_OVERRIDE:-}"
CANDIDATE_SOURCE_LIMIT_OVERRIDE="${CANDIDATE_SOURCE_LIMIT_OVERRIDE:-}"
PAPER_SPARSE_RRF_WEIGHT_OVERRIDE="${PAPER_SPARSE_RRF_WEIGHT_OVERRIDE:-}"
PAPER_DENSE_RRF_WEIGHT_OVERRIDE="${PAPER_DENSE_RRF_WEIGHT_OVERRIDE:-}"
CHUNK_AGGREGATED_RRF_WEIGHT_OVERRIDE="${CHUNK_AGGREGATED_RRF_WEIGHT_OVERRIDE:-}"
LITERAL_ENTITY_RRF_WEIGHT_OVERRIDE="${LITERAL_ENTITY_RRF_WEIGHT_OVERRIDE:-}"
EXACT_PHRASE_RRF_WEIGHT_OVERRIDE="${EXACT_PHRASE_RRF_WEIGHT_OVERRIDE:-}"
ASPECT_COVERAGE_BONUS_OVERRIDE="${ASPECT_COVERAGE_BONUS_OVERRIDE:-}"
SOURCE_DIVERSITY_BONUS_OVERRIDE="${SOURCE_DIVERSITY_BONUS_OVERRIDE:-}"
LITERAL_ENTITY_BONUS_OVERRIDE="${LITERAL_ENTITY_BONUS_OVERRIDE:-}"
EXACT_PHRASE_BONUS_OVERRIDE="${EXACT_PHRASE_BONUS_OVERRIDE:-}"
EVIDENCE_SPARSE_WEIGHT_OVERRIDE="${EVIDENCE_SPARSE_WEIGHT_OVERRIDE:-}"
EVIDENCE_DENSE_WEIGHT_OVERRIDE="${EVIDENCE_DENSE_WEIGHT_OVERRIDE:-}"
EVIDENCE_RERANKER_WEIGHT_OVERRIDE="${EVIDENCE_RERANKER_WEIGHT_OVERRIDE:-}"
EVIDENCE_RERANKER_CANDIDATE_CHUNKS_OVERRIDE="${EVIDENCE_RERANKER_CANDIDATE_CHUNKS_OVERRIDE:-}"
EVIDENCE_CHUNK_TEXT_LIMIT_OVERRIDE="${EVIDENCE_CHUNK_TEXT_LIMIT_OVERRIDE:-}"

PROJECT_ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
VENV_DIR="${VENV_DIR:-$PROJECT_ROOT/.venv}"
CLI_BIN="${CLI_BIN:-$VENV_DIR/bin/paper-search-agent}"
TRACE_DIR="$PROJECT_ROOT/data/traces"

set_env_if_nonempty() {
  local name="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    export "$name=$value"
  fi
}

if [[ ! -x "$CLI_BIN" ]]; then
  print -u2 "CLI not found: $CLI_BIN"
  exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$PROJECT_ROOT/logs"
fi

mkdir -p "$OUTPUT_DIR"

if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$OUTPUT_DIR/${OUTPUT_PREFIX}_$(date +%Y%m%d_%H%M%S).json"
fi

export PAPER_SEARCH_AGENT_LOG_LEVEL="$LOG_LEVEL"

set_env_if_nonempty "PAPER_SEARCH_AGENT_DATA_DIR" "$DATA_DIR_OVERRIDE"
set_env_if_nonempty "OPENAI_BASE_URL" "$OPENAI_BASE_URL_OVERRIDE"
set_env_if_nonempty "OPENAI_MODEL" "$OPENAI_MODEL_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_REQUEST_TIMEOUT" "$REQUEST_TIMEOUT_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_PAPER_DENSE_MODEL" "$PAPER_DENSE_MODEL_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_CHUNK_DENSE_MODEL" "$CHUNK_DENSE_MODEL_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_DENSE_DEVICE" "$DENSE_DEVICE_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_DENSE_BATCH_SIZE" "$DENSE_BATCH_SIZE_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_RERANKER_ENABLED" "$RERANKER_ENABLED_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_RERANKER_MODEL" "$RERANKER_MODEL_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_RERANKER_DEVICE" "$RERANKER_DEVICE_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_RERANKER_BATCH_SIZE" "$RERANKER_BATCH_SIZE_OVERRIDE"

set_env_if_nonempty "PAPER_SEARCH_AGENT_CANDIDATE_POOL_SIZE" "$CANDIDATE_POOL_SIZE_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_CANDIDATE_SOURCE_LIMIT" "$CANDIDATE_SOURCE_LIMIT_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_PAPER_SPARSE_RRF_WEIGHT" "$PAPER_SPARSE_RRF_WEIGHT_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_PAPER_DENSE_RRF_WEIGHT" "$PAPER_DENSE_RRF_WEIGHT_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_CHUNK_AGGREGATED_RRF_WEIGHT" "$CHUNK_AGGREGATED_RRF_WEIGHT_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_LITERAL_ENTITY_RRF_WEIGHT" "$LITERAL_ENTITY_RRF_WEIGHT_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_EXACT_PHRASE_RRF_WEIGHT" "$EXACT_PHRASE_RRF_WEIGHT_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_ASPECT_COVERAGE_BONUS" "$ASPECT_COVERAGE_BONUS_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_SOURCE_DIVERSITY_BONUS" "$SOURCE_DIVERSITY_BONUS_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_LITERAL_ENTITY_BONUS" "$LITERAL_ENTITY_BONUS_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_EXACT_PHRASE_BONUS" "$EXACT_PHRASE_BONUS_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_EVIDENCE_SPARSE_WEIGHT" "$EVIDENCE_SPARSE_WEIGHT_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_EVIDENCE_DENSE_WEIGHT" "$EVIDENCE_DENSE_WEIGHT_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_EVIDENCE_RERANKER_WEIGHT" "$EVIDENCE_RERANKER_WEIGHT_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_EVIDENCE_RERANKER_CANDIDATE_CHUNKS" "$EVIDENCE_RERANKER_CANDIDATE_CHUNKS_OVERRIDE"
set_env_if_nonempty "PAPER_SEARCH_AGENT_EVIDENCE_CHUNK_TEXT_LIMIT" "$EVIDENCE_CHUNK_TEXT_LIMIT_OVERRIDE"

cd "$PROJECT_ROOT"

command=("$CLI_BIN" "search" "--query" "$QUERY" "--top-k" "$TOP_K")

print "project_root : $PROJECT_ROOT"
print "query        : $QUERY"
print "top_k        : $TOP_K"
print "output_file  : $OUTPUT_FILE"
print "openai_model : ${OPENAI_MODEL_OVERRIDE:-config/.env default}"
print "data_dir     : ${DATA_DIR_OVERRIDE:-config.toml default}"
print ""

if [[ "$SAVE_OUTPUT" == "1" ]]; then
  "${command[@]}" | tee "$OUTPUT_FILE"
else
  "${command[@]}"
fi

if [[ "$SAVE_OUTPUT" == "1" && "$PRINT_SUMMARY" == "1" ]]; then
  python3 - "$OUTPUT_FILE" "$TRACE_DIR" <<'PY'
import json
import sys
from pathlib import Path

output_path = Path(sys.argv[1])
trace_dir = Path(sys.argv[2])
payload = json.loads(output_path.read_text(encoding="utf-8"))

trace_id = payload.get("trace_id", "")
satisfied = payload.get("satisfied", [])
partial = payload.get("partial", [])
rejected = payload.get("rejected", [])

print()
print("summary")
print(f"trace_id     : {trace_id}")
print(f"satisfied    : {len(satisfied)}")
print(f"partial      : {len(partial)}")
print(f"rejected     : {len(rejected)}")
print(f"saved_result : {output_path}")

trace_path = trace_dir / f"{trace_id}.json"
if trace_id and trace_path.exists():
    print(f"trace_file   : {trace_path}")

if satisfied:
    top = satisfied[0]
    print(f"top_paper    : {top.get('paper_id', '')}")
    print(f"top_verdict  : {top.get('verdict', '')}")
    print(f"top_score    : {top.get('score', '')}")
PY
fi
