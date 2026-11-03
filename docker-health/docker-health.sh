#!/usr/bin/env bash
# docker-health：重启 running 且 unhealthy 的容器（每个最多 RESTART_MAX 次），重启与恢复时执行 CMD 通知。
# NOTIFY_EXITED=true 时，exited 容器只通知一次不重启，重新运行后再通知一次。
# 每 INTERVAL 秒检查一轮；INTERVAL=0 时只检查一轮，有错误则退出码非零。

set -u

interval=${INTERVAL:-60}
restart_max=${RESTART_MAX:-3}
docker_timeout=${DOCKER_TIMEOUT:-60}
cmd=${CMD:-}
cmd_timeout=${CMD_TIMEOUT:-30}
notify_exited=${NOTIFY_EXITED:-false}
# 状态文件按容器完整 ID 命名，内容：<已重启次数> <首次重启时间戳> <首次重启时间>
state_dir=/tmp/docker-health
# 已通知的 exited 容器，文件按完整 ID 命名，内容：<发现退出时间戳> <发现退出时间>
exited_dir=/tmp/docker-health-exited

check_int() {
    case "$2" in ''|*[!0-9]*) ;; *) [ "$2" -ge "$3" ] && return 0 ;; esac
    printf '无效的 %s：%s\n' "$1" "$2" >&2
    exit 1
}
check_int INTERVAL "$interval" 0
check_int RESTART_MAX "$restart_max" 1
check_int DOCKER_TIMEOUT "$docker_timeout" 1
check_int CMD_TIMEOUT "$cmd_timeout" 1
case "$notify_exited" in
    true|True|TRUE|1) notify_exited=1 ;;
    false|False|FALSE|0) notify_exited=0 ;;
    *) printf '无效的 NOTIFY_EXITED：%s\n' "$notify_exited" >&2; exit 1 ;;
esac

now() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { printf '%s %s\n' "$(now)" "$*"; }
dk() { timeout "$docker_timeout" docker "$@" </dev/null; }

host_name=$(dk info --format '{{.Name}}') || { echo 'docker 不可用，退出' >&2; exit 1; }
mkdir -p "$state_dir" "$exited_dir" || exit 1

# 健康检查日志各条输出以 \x1e 分隔，取最后一条作为 HEALTH_OUTPUT。
inspect_format='{{.Name}}|{{.Config.Image}}|{{index .Config.Labels "docker-health"}}|{{.State.Status}}|{{.State.ExitCode}}|{{with .State.Health}}{{.Status}}|{{.FailingStreak}}{{range .Log}}{{"\x1e"}}{{.Output}}{{end}}{{else}}none|0{{end}}'

inspect() {
    local info head
    info=$(dk inspect --type container --format "$inspect_format" "$id") || return 1
    head=${info%%$'\x1e'*}
    IFS='|' read -r name image label status exit_code health streak <<<"$head"
    name=${name#/}
    health_output=''
    [ "$head" = "$info" ] || health_output=${info##*$'\x1e'}
    health_output=${health_output%$'\n'}
    health_output=${health_output:0:1000}
}

# 执行回调；输出被捕获，成功只记结果，失败附完整输出。变量说明见 README。
notify() {
    [ -n "$cmd" ] || return 0
    local output rc result
    output=$(EVENT="$event" EVENT_TIME="$event_time" HOST_NAME="$host_name" \
        CONTAINER_ID="$id" CONTAINER_NAME="$name" CONTAINER_IMAGE="$image" \
        HEALTH_STATUS="$health" HEALTH_OUTPUT="$health_output" FAILING_STREAK="$streak" \
        RESTART_ATTEMPT="$attempts" RESTART_MAX="$restart_max" RESTART_RESULT="$restart_result" \
        FIRST_RESTART_TIME="$first_time" DOWNTIME_SECONDS="$downtime" MESSAGE="$message" \
        CONTAINER_STATUS="$status" EXIT_CODE="$exit_code" EXITED_TIME="$exited_time" \
        timeout -k 5 "$cmd_timeout" sh -c "$cmd" 2>&1 </dev/null)
    rc=$?
    if [ "$rc" -eq 0 ]; then
        log "event=$event container=$name cmd=success"
        return 0
    fi
    case "$rc" in 124|137) result=timeout ;; *) result=failed ;; esac
    log "event=$event container=$name cmd=$result code=$rc output:"
    printf '%s\n' "$output"
    return 1
}

# 处理单个容器：unhealthy 则重启，有重启记录且已 healthy 则记为恢复；
# 开启 NOTIFY_EXITED 时，exited 只通知一次，重新 running（healthy 或无 healthcheck）后通知恢复。
# 每轮每个容器最多一个事件，其他状态（starting 等）等待下一轮。
handle() {
    id=$1
    local state_file=$state_dir/$1 exited_file=$exited_dir/$1 first_epoch='' exited_epoch='' detail
    attempts=0 first_time='' restart_result='' downtime='' exited_time=''
    [ -f "$state_file" ] && read -r attempts first_epoch first_time <"$state_file"
    case "$attempts" in ''|*[!0-9]*) attempts=0 ;; esac
    [ -f "$exited_file" ] && read -r exited_epoch exited_time <"$exited_file"
    if ! inspect; then
        log "container=$id error=inspect_failed"
        return 1
    fi
    case "$label" in false|False|FALSE) return 0 ;; esac

    if [ "$status" = exited ]; then
        [ "$notify_exited" -eq 1 ] && [ ! -f "$exited_file" ] || return 0
        exited_time=$(now)
        printf '%s %s\n' "$(date +%s)" "$exited_time" >"$exited_file" || return 1
        event=exited
        detail="exit_code=$exit_code"
        message="$host_name 容器 $name 已退出，退出码 $exit_code"
    elif [ "$status $health" = 'running unhealthy' ]; then
        [ "$attempts" -lt "$restart_max" ] || return 0
        attempts=$((attempts + 1))
        if [ "$attempts" -eq 1 ]; then
            first_epoch=$(date +%s)
            first_time=$(now)
        fi
        # 先记次数再重启，失败的重启也占用额度。
        printf '%s %s %s\n' "$attempts" "$first_epoch" "$first_time" >"$state_file" || return 1
        dk restart "$id" >/dev/null
        case $? in 0) restart_result=success ;; 124) restart_result=timeout ;; *) restart_result=failed ;; esac
        event=restart
        message="$host_name 容器 $name 不健康，第 $attempts/$restart_max 次重启：$restart_result"
        [ "$attempts" -lt "$restart_max" ] || message="$message，已达上限，不再自动重启"
        detail="attempt=$attempts/$restart_max result=$restart_result"
    elif [ "$status $health" = 'running healthy' ] && [ "$attempts" -gt 0 ]; then
        rm -f -- "$state_file" || return 1
        downtime=$(($(date +%s) - ${first_epoch:-0}))
        event=recovered
        message="$host_name 容器 $name 已恢复健康，共重启 $attempts 次，距首次重启 $downtime 秒"
        detail="attempt=$attempts/$restart_max downtime=${downtime}s"
    elif [ -f "$exited_file" ] && [ "$status" = running ] && { [ "$health" = healthy ] || [ "$health" = none ]; }; then
        rm -f -- "$exited_file" || return 1
        downtime=$(($(date +%s) - ${exited_epoch:-0}))
        event=exited_recovered
        message="$host_name 容器 $name 已重新运行，距发现退出 $downtime 秒"
        detail="downtime=${downtime}s"
    else
        return 0
    fi
    event_time=$(now)
    log "event=$event container=$name id=${id:0:12} $detail"
    notify
}

check_once() {
    local all unhealthy exited file errors=0
    all=$(dk ps -aq --no-trunc) || { log 'error=docker_ps_failed'; return 1; }
    unhealthy=$(dk ps -q --no-trunc --filter status=running --filter health=unhealthy) || {
        log 'error=docker_ps_failed'
        return 1
    }
    exited=''
    if [ "$notify_exited" -eq 1 ]; then
        exited=$(dk ps -q --no-trunc --filter status=exited) || { log 'error=docker_ps_failed'; return 1; }
    fi
    # 容器已删除则丢弃其记录。
    for file in "$state_dir"/* "$exited_dir"/*; do
        [ -f "$file" ] || continue
        grep -qxF "${file##*/}" <<<"$all" || rm -f -- "$file"
    done
    # 待处理：当前 unhealthy、exited 的容器 + 有记录的容器（用于恢复检查）。
    for id in $({ printf '%s\n' "$unhealthy" "$exited"; ls "$state_dir"; ls "$exited_dir"; } | sort -u); do
        handle "$id" || errors=1
    done
    return "$errors"
}

# 作为 PID 1 需显式处理信号；检查与 sleep 放后台 wait，以便及时响应 docker stop。
trap 'exit 0' TERM INT
log "start host=$host_name interval=$interval restart_max=$restart_max notify_exited=$notify_exited"
while :; do
    check_once &
    wait $!
    rc=$?
    [ "$interval" -gt 0 ] || exit "$rc"
    sleep "$interval" &
    wait $!
done
