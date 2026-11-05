#!/usr/bin/env bash
# watchexec 包装：WATCH 中的路径变更后执行 CMD。
# 自首个变更起 DEBOUNCE 时间内的变更合并为一次，窗口结束时执行；执行中再有变更，结束后补执行一次。
# CMD 输出被捕获：成功只记一行，失败或超时附完整输出，并可执行 FAIL_CMD 通知。
# 容器参数（compose 的 command）作为额外选项传给 watchexec。

set -u

now() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { printf '%s %s\n' "$(now)" "$*"; }

# 执行 $1 并记录结果，$2 为日志名，$3 为超时秒数（0 不限）；返回命令退出码，输出留在 $output。
run() {
    local rc start ms result
    start=$(date +%s%N)
    output=$(timeout -k 5 "$3" bash -c "$1" 2>&1 </dev/null)
    rc=$?
    ms=$((($(date +%s%N) - start) / 1000000))
    if [ "$rc" -eq 0 ]; then
        log "$2=success duration=${ms}ms"
    else
        case "$rc" in 124|137) result=timeout ;; *) result=failed ;; esac
        log "$2=$result code=$rc duration=${ms}ms output:"
        [ -z "$output" ] || printf '%s\n' "$output"
    fi
    return "$rc"
}

# watchexec 每次触发时以 __run 调用本脚本，变量已在启动时校验。
if [ "${1:-}" = __run ]; then
    run "$CMD" cmd "${CMD_TIMEOUT:-60}" && exit 0
    rc=$?
    [ -n "${FAIL_CMD:-}" ] || exit "$rc"
    EXIT_CODE=$rc OUTPUT=${output:0:1000} MESSAGE="watchexec ${WATCH:-} 变更后执行命令失败，退出码 $rc" \
        run "$FAIL_CMD" fail_cmd "${FAIL_CMD_TIMEOUT:-60}"
    exit "$rc"
fi

check_int() {
    case "$2" in ''|*[!0-9]*) printf '无效的 %s：%s\n' "$1" "$2" >&2; exit 1 ;; esac
}

watch=${WATCH:-}
cmd=${CMD:-}
debounce=${DEBOUNCE:-1}
ignore=${IGNORE:-}
[ -n "$watch" ] || { echo '缺少 WATCH：监听的目录或文件' >&2; exit 1; }
[ -n "$cmd" ] || { echo '缺少 CMD：变更后执行的命令' >&2; exit 1; }
check_int CMD_TIMEOUT "${CMD_TIMEOUT:-60}"
check_int FAIL_CMD_TIMEOUT "${FAIL_CMD_TIMEOUT:-60}"
# 纯数字按秒，其余原样交给 watchexec（如 500ms、1min 30s）
case "$debounce" in ''|*[!0-9]*) ;; *) debounce=${debounce}s ;; esac

args=()
read -r -d '' -a paths <<<"$watch"
for p in "${paths[@]}"; do
    [ -e "$p" ] || { printf '监听路径不存在：%s\n' "$p" >&2; exit 1; }
    args+=(-w "$p")
done
# 默认忽略 .DS_Store，IGNORE 追加忽略规则（gitignore 语法，空白分隔）
args+=(-i '**/.DS_Store')
read -r -d '' -a patterns <<<"$ignore"
for p in "${patterns[@]}"; do args+=(-i "$p"); done

log "start watch=$watch debounce=$debounce ignore=.DS_Store${ignore:+ $ignore} cmd_timeout=${CMD_TIMEOUT:-60}s"
# -p 启动时不执行；-q 不打印 watchexec 自身的启停信息
exec watchexec -q -p --on-busy-update=queue --debounce "$debounce" "${args[@]}" "$@" \
    --shell=none -- "$0" __run
