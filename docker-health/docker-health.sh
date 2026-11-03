#!/usr/bin/env bash
# Docker 容器健康检查
# 容器内常驻，每 INTERVAL 秒检查一轮；INTERVAL=0 时仅检查一轮并以本轮结果退出。

set -u

state_dir=${HEALTH_STATE_DIR:-/tmp/docker-health-state}
log_file=${HEALTH_LOG_FILE:-/dev/stdout}
cmd=${CMD:-}
docker_timeout=${DOCKER_TIMEOUT:-60}
interval=${INTERVAL:-60}
timeout_file=$state_dir/timeouts

case "$interval" in ''|*[!0-9]*) printf '无效的 INTERVAL：%s\n' "$interval" >&2; exit 1 ;; esac
for dependency in docker timeout; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf '缺少必要命令：%s\n' "$dependency" >&2
        exit 1
    fi
done
if ! timeout "$docker_timeout" docker version --format '{{.Server.Version}}' >/dev/null; then
    echo 'docker 不可用，退出' >&2
    exit 1
fi
mkdir -p "$state_dir" || exit 1
# fd 3 指向日志，命令替换内的事件也能写到日志而不被捕获。
exec 3>>"$log_file" || exit 1

write_attempts() {
    local file=$1 value=$2 tmp=$1.tmp.$$
    if printf '%s\n' "$value" >"$tmp" && mv -f -- "$tmp" "$file"; then return 0; fi
    rm -f -- "$tmp"
    return 1
}

read_attempts() {
    attempts=0
    if [ -f "$state_file" ]; then
        read -r attempts < "$state_file" || attempts=0
    fi
    case "$attempts" in 0|1|2|3) return 0 ;; esac
    printf '无效的重启计数文件：%s\n' "$state_file" >&2
    return 1
}

run_cmd() {
    [ -n "$cmd" ] || return 0
    env CONTAINER_NAME="$container_name" CONTAINER_ID="$container_id" "$@" sh -c "$cmd" && return 0
    printf '容器 %s 的 CMD 执行失败\n' "$container_name" >&2
    return 1
}

# 连续超时计数跨轮保存；超过 3 次只记日志不再回调，docker 恢复响应后发恢复通知并清零。
on_timeout() {
    local event_time count=0
    [ -f "$timeout_file" ] && { read -r count < "$timeout_file" || count=0; }
    count=$((count + 1))
    write_attempts "$timeout_file" "$count"
    event_time=$(date '+%Y-%m-%dT%H:%M:%S%z')
    printf '%s container=%s id=%s event=timeout command="%s" count=%s\n' \
        "$event_time" "$container_name" "$container_id" "$1" "$count" >&3
    [ "$count" -le 3 ] || return 0
    run_cmd EVENT_TIME="$event_time" CONTAINER_EVENT=timeout DOCKER_COMMAND="$1" RECOVERY_TIME='' \
        RESTART_TIME='' RESTART_ATTEMPT=0 RESTART_RESULT='' CONTAINER_STATUS='' >&3
}

on_docker_ok() {
    [ -f "$timeout_file" ] || return 0
    local event_time count=0 container_name='' container_id=''
    read -r count < "$timeout_file" || count=0
    rm -f -- "$timeout_file" || return 1
    event_time=$(date '+%Y-%m-%dT%H:%M:%S%z')
    printf '%s event=docker_recovered timeouts=%s\n' "$event_time" "$count" >&3
    run_cmd EVENT_TIME="$event_time" CONTAINER_EVENT=docker_recovered RECOVERY_TIME="$event_time" \
        RESTART_TIME='' RESTART_ATTEMPT=0 RESTART_RESULT='' CONTAINER_STATUS='' >&3
}

# 查询类 docker 命令，第一个参数为事件中的命令名；timeout 超时返回 124。
dk() {
    local name=$1 rc
    shift
    timeout "$docker_timeout" docker "$@"
    rc=$?
    if [ "$rc" -eq 124 ]; then on_timeout "$name"; else on_docker_ok; fi
    return "$rc"
}

# 单轮检查，需在子 shell 中运行：exit 只结束本轮。
check_once() {
    result=0
    container_id='' container_name=''

    # 只取运行中且 unhealthy 的容器；退出的容器由 restart 策略拉起，人工停止的保持停止。
    unhealthy=$(dk 'docker ps' ps --filter status=running --filter health=unhealthy --no-trunc \
        --format '{{.ID}} {{.Names}} {{.Label "docker-health"}}') || exit 1
    while read -r container_id container_name label; do
        [ -n "$container_id" ] || continue
        case "$label" in false|False) continue ;; esac
        result=1
        state_file=$state_dir/$container_id
        read_attempts || continue
        [ "$attempts" -lt 3 ] || continue
        # 先记录次数，失败的重启也占用额度，防止持续异常无限重试。
        attempts=$((attempts + 1))
        write_attempts "$state_file" "$attempts" || continue
        # restart 超时多为容器停止慢，只记为重启结果，不计入 docker 超时。
        timeout "$docker_timeout" docker restart "$container_id" >/dev/null
        case $? in
            0) restart_result=success ;;
            124) restart_result=timeout ;;
            *) restart_result=failed ;;
        esac
        restart_time=$(date '+%Y-%m-%dT%H:%M:%S%z')
        printf '%s container=%s attempt=%s result=%s status="unhealthy"\n' \
            "$restart_time" "$container_name" "$attempts" "$restart_result" >> "$log_file"
        run_cmd EVENT_TIME="$restart_time" CONTAINER_EVENT=restart RECOVERY_TIME='' \
            RESTART_TIME="$restart_time" RESTART_ATTEMPT="$attempts" \
            RESTART_RESULT="$restart_result" CONTAINER_STATUS=unhealthy
    done <<EOF_UNHEALTHY
$unhealthy
EOF_UNHEALTHY

    # 恢复检查只针对有重启记录的容器；容器已删除则清理其状态文件。
    container_id='' container_name=''
    all_ids=$(dk 'docker ps -a' ps -aq --no-trunc) || exit 1
    for state_file in "$state_dir"/*; do
        container_id=${state_file##*/}
        case "$container_id" in timeouts|*.tmp.*|'*') continue ;; esac
        case "$all_ids" in *"$container_id"*) ;; *)
            rm -f -- "$state_file" || result=1
            continue
            ;;
        esac
        container_name=''
        status=$(dk 'docker inspect' inspect --format '{{.Name}} {{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id") || {
            result=1
            continue
        }
        container_name=${status%% *}
        container_name=${container_name#/}
        status=${status#* }
        [ "$status" = 'running healthy' ] || continue
        read_attempts || { result=1; continue; }
        if [ "$attempts" -gt 0 ]; then
            recovery_time=$(date '+%Y-%m-%dT%H:%M:%S%z')
            # 日志写入成功后才删除记录，避免写入失败后丢失恢复事件。
            if ! printf '%s container=%s event=recovered status="healthy"\n' \
                "$recovery_time" "$container_name" >> "$log_file"; then
                result=1
                continue
            fi
        fi
        rm -f -- "$state_file" || { result=1; continue; }
        [ "$attempts" -gt 0 ] || continue
        run_cmd EVENT_TIME="$recovery_time" CONTAINER_EVENT=recovered RECOVERY_TIME="$recovery_time" \
            RESTART_TIME='' RESTART_ATTEMPT=0 RESTART_RESULT='' CONTAINER_STATUS=healthy || result=1
    done
    exit "$result"
}

# 作为 PID 1 运行时需显式处理信号；检查与 sleep 均放后台 wait，以便及时响应 docker stop。
trap 'exit 0' TERM INT
while :; do
    ( check_once ) &
    wait $!
    rc=$?
    [ "$interval" -gt 0 ] || exit "$rc"
    sleep "$interval" &
    wait $!
done
