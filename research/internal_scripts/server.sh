#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$ROOT_DIR/logs"
STATE_FILE="$LOG_DIR/demo_server_state.env"
BACKEND_LOG="$LOG_DIR/demo_backend_runtime.log"
FRONTEND_LOG="$LOG_DIR/demo_frontend_runtime.log"
BACKEND_PORT="${PAPERSCOUT_BACKEND_PORT:-4001}"
FRONTEND_PORT="${PAPERSCOUT_FRONTEND_PORT:-4000}"
BACKEND_START_TIMEOUT="${PAPERSCOUT_BACKEND_START_TIMEOUT:-90}"
NODE_BIN_DIR="${PAPERSCOUT_NODE_BIN_DIR:-/workspace/tools/node-v20.19.0-linux-x64/bin}"
CACHE_ROOT="${PAPERSCOUT_CACHE_ROOT:-/workspace/caches}"
PUBLIC_HOST="${PAPERSCOUT_PUBLIC_HOST:-171.231.22.80}"
BACKEND_PATTERN="uvicorn paperscout.api:app --host 127.0.0.1 --port ${BACKEND_PORT}"
BACKEND_LEGACY_PATTERN="scripts/run_api_server.py --host 0.0.0.0 --port ${BACKEND_PORT}"
FRONTEND_NPM_PATTERN="npm run start -- --hostname 0.0.0.0 --port ${FRONTEND_PORT}"

if [[ -d "$NODE_BIN_DIR" ]]; then
  export PATH="$NODE_BIN_DIR:$PATH"
fi

export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$CACHE_ROOT}"
export HF_HOME="${HF_HOME:-$CACHE_ROOT/huggingface}"
export HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE:-$HF_HOME/hub}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-$HF_HOME/transformers}"
export TORCH_HOME="${TORCH_HOME:-$CACHE_ROOT/torch}"

mkdir -p "$LOG_DIR"
mkdir -p "$XDG_CACHE_HOME" "$HF_HOME" "$HUGGINGFACE_HUB_CACHE" "$TRANSFORMERS_CACHE" "$TORCH_HOME"

usage() {
  cat <<USAGE
用法:
  ./server.sh start   启动 demo 前后端
  ./server.sh stop    关闭 demo 前后端
  ./server.sh status  查看当前状态
USAGE
}

pid_is_alive() {
  local pid="${1:-}"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

save_state() {
  cat > "$STATE_FILE" <<STATE
BACKEND_PID=${BACKEND_PID:-}
FRONTEND_PID=${FRONTEND_PID:-}
STATE
}

clear_state() {
  rm -f "$STATE_FILE"
}

backend_pid() {
  load_state
  if pid_is_alive "${BACKEND_PID:-}"; then
    echo "$BACKEND_PID"
    return 0
  fi
  pgrep -f "$BACKEND_PATTERN" | head -n 1 || \
    pgrep -f "$BACKEND_LEGACY_PATTERN" | head -n 1 || \
    lsof -tiTCP:${BACKEND_PORT} -sTCP:LISTEN 2>/dev/null | head -n 1 || true
}

frontend_pid() {
  load_state
  if pid_is_alive "${FRONTEND_PID:-}"; then
    echo "$FRONTEND_PID"
    return 0
  fi
  pgrep -f 'next-server' | head -n 1 || \
    pgrep -f "$FRONTEND_NPM_PATTERN" | head -n 1 || true
}

require_prereqs() {
  if [[ ! -x "$ROOT_DIR/.venv/bin/python" ]]; then
    echo "错误: 缺少 Python 虚拟环境: $ROOT_DIR/.venv/bin/python"
    exit 1
  fi
  if [[ ! -x "$ROOT_DIR/apps/web/node_modules/.bin/next" ]]; then
    echo "错误: 缺少前端依赖，请先在 apps/web 下安装 node_modules。"
    exit 1
  fi
  if [[ ! -f "$ROOT_DIR/apps/web/.next/BUILD_ID" ]]; then
    echo "错误: 前端尚未 build，请先执行: cd apps/web && npm run build"
    exit 1
  fi
}

wait_for_http() {
  local url="$1"
  local timeout_seconds="$2"
  local i
  for ((i=1; i<=timeout_seconds; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

stop_backend_by_pid() {
  local pid="${1:-}"
  if [[ -z "$pid" ]]; then
    pid="$(backend_pid)"
    if [[ -z "$pid" ]]; then
      return 0
    fi
  fi
  kill "$pid" 2>/dev/null || true
  sleep 1
  if pid_is_alive "$pid"; then
    kill -9 "$pid" 2>/dev/null || true
  fi
  pkill -f "$BACKEND_PATTERN" 2>/dev/null || true
  pkill -f "$BACKEND_LEGACY_PATTERN" 2>/dev/null || true
  local port_pid
  port_pid="$(lsof -tiTCP:${BACKEND_PORT} -sTCP:LISTEN 2>/dev/null | head -n 1 || true)"
  if [[ -n "$port_pid" ]]; then
    kill "$port_pid" 2>/dev/null || true
    sleep 1
    if pid_is_alive "$port_pid"; then
      kill -9 "$port_pid" 2>/dev/null || true
    fi
  fi
}

stop_frontend_by_pid() {
  local pid="${1:-}"
  if [[ -z "$pid" ]]; then
    return 0
  fi
  kill "$pid" 2>/dev/null || true
  sleep 1
  if pid_is_alive "$pid"; then
    kill -9 "$pid" 2>/dev/null || true
  fi
  pkill -f 'next-server' 2>/dev/null || true
  pkill -f "$FRONTEND_NPM_PATTERN" 2>/dev/null || true
}

start_backend_process() {
  nohup env \
    PAPERSCOUT_DENSE_DEVICE="${PAPERSCOUT_SERVICE_DENSE_DEVICE:-cpu}" \
    PAPERSCOUT_RERANKER_DEVICE="${PAPERSCOUT_SERVICE_RERANKER_DEVICE:-cuda:0}" \
    TOKENIZERS_PARALLELISM="${TOKENIZERS_PARALLELISM:-false}" \
    PAPERSCOUT_API_BASE_URL="http://127.0.0.1:${BACKEND_PORT}/api" \
    XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
    HF_HOME="${HF_HOME}" \
    HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE}" \
    TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE}" \
    TORCH_HOME="${TORCH_HOME}" \
    "$ROOT_DIR/.venv/bin/python" -m uvicorn paperscout.api:app --host 127.0.0.1 --port "${BACKEND_PORT}" > "$BACKEND_LOG" 2>&1 < /dev/null &
  BACKEND_PID=$!
  echo "已启动后端，PID=$BACKEND_PID"
}

start_frontend_process() {
  nohup bash -lc "cd '$ROOT_DIR/apps/web' && export PATH='$NODE_BIN_DIR':\"\$PATH\" && export PAPERSCOUT_API_BASE_URL='http://127.0.0.1:${BACKEND_PORT}/api' && exec ./node_modules/.bin/next start --hostname 0.0.0.0 --port ${FRONTEND_PORT}" > "$FRONTEND_LOG" 2>&1 < /dev/null &
  FRONTEND_PID=$!
  echo "已启动前端，PID=$FRONTEND_PID"
}

print_status() {
  local bpid fpid
  bpid="$(backend_pid)"
  fpid="$(frontend_pid)"

  if [[ -n "$bpid" || -n "$fpid" ]]; then
    echo "demo 当前状态: 运行中"
  else
    echo "demo 当前状态: 已停止"
  fi

  if [[ -n "$bpid" ]]; then
    echo "后端 PID : $bpid"
  else
    echo "后端 PID : 未运行"
  fi

  if [[ -n "$fpid" ]]; then
    echo "前端 PID : $fpid"
  else
    echo "前端 PID : 未运行"
  fi

  if curl -fsS http://127.0.0.1:${FRONTEND_PORT}/api/health >/dev/null 2>&1; then
    echo "健康检查 : 正常"
    echo "访问地址 : http://${PUBLIC_HOST}:${FRONTEND_PORT}"
  else
    echo "健康检查 : 未通过"
  fi

  echo "后端日志 : $BACKEND_LOG"
  echo "前端日志 : $FRONTEND_LOG"
}

start_demo() {
  require_prereqs

  local existing_backend existing_frontend
  local backend_started_now=0 frontend_started_now=0

  existing_backend="$(backend_pid)"
  if [[ -n "$existing_backend" ]]; then
    BACKEND_PID="$existing_backend"
    if wait_for_http http://127.0.0.1:${BACKEND_PORT}/openapi.json 3; then
      echo "后端已在运行，PID=$BACKEND_PID"
    else
      echo "检测到后端进程但接口未就绪，正在重启后端。"
      stop_backend_by_pid "$BACKEND_PID"
      start_backend_process
      backend_started_now=1
    fi
  else
    start_backend_process
    backend_started_now=1
  fi

  if ! wait_for_http http://127.0.0.1:${BACKEND_PORT}/openapi.json "${BACKEND_START_TIMEOUT}"; then
    echo "错误: 后端启动失败，请查看日志: $BACKEND_LOG"
    tail -n 40 "$BACKEND_LOG" || true
    stop_backend_by_pid "${BACKEND_PID:-}"
    clear_state
    exit 1
  fi

  existing_frontend="$(frontend_pid)"
  if [[ -n "$existing_frontend" ]]; then
    FRONTEND_PID="$existing_frontend"
    if wait_for_http http://127.0.0.1:${FRONTEND_PORT}/api/health 3; then
      echo "前端已在运行，PID=$FRONTEND_PID"
    else
      echo "检测到前端进程但接口未就绪，正在重启前端。"
      stop_frontend_by_pid "$FRONTEND_PID"
      start_frontend_process
      frontend_started_now=1
    fi
  else
    start_frontend_process
    frontend_started_now=1
  fi

  if ! wait_for_http http://127.0.0.1:${FRONTEND_PORT}/api/health 30; then
    echo "错误: 前端启动失败或前后端未连通，请查看日志: $FRONTEND_LOG"
    tail -n 40 "$FRONTEND_LOG" || true
    if [[ "$frontend_started_now" -eq 1 ]]; then
      stop_frontend_by_pid "${FRONTEND_PID:-}"
    fi
    if [[ "$backend_started_now" -eq 1 ]]; then
      stop_backend_by_pid "${BACKEND_PID:-}"
    fi
    clear_state
    exit 1
  fi

  save_state

  if [[ "$backend_started_now" -eq 0 && "$frontend_started_now" -eq 0 ]]; then
    echo "demo 已经在运行，无需重复启动。"
  else
    echo "demo 启动完成。"
  fi
  echo "访问地址: http://${PUBLIC_HOST}:${FRONTEND_PORT}"
}

stop_demo() {
  local bpid fpid stopped_any=0
  bpid="$(backend_pid)"
  fpid="$(frontend_pid)"

  if [[ -n "$fpid" ]]; then
    stop_frontend_by_pid "$fpid"
    stopped_any=1
    echo "前端已停止。"
  else
    echo "前端本来就没有运行。"
  fi

  if [[ -n "$bpid" ]]; then
    stop_backend_by_pid "$bpid"
    stopped_any=1
    echo "后端已停止。"
  else
    echo "后端本来就没有运行。"
  fi

  clear_state

  if [[ "$stopped_any" -eq 0 ]]; then
    echo "demo 已经是停止状态，无需重复关闭。"
  else
    echo "demo 已关闭。"
  fi
}

case "${1:-}" in
  start)
    start_demo
    ;;
  stop)
    stop_demo
    ;;
  status)
    print_status
    ;;
  *)
    usage
    exit 1
    ;;
esac
