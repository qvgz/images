# docker-health

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/qvgz/docker-health)

常驻容器：发现 running 且 unhealthy 的容器即重启（每个最多 `RESTART_MAX` 次），重启与恢复时执行 `CMD` 通知；可选通知 exited 容器（不重启）。示例见 [compose.yaml](./compose.yaml)。

```bash
docker run -d --name docker-health --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e TZ=Asia/Shanghai -l docker-health=false qvgz/docker-health
```

## 变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `INTERVAL` | `60` | 检查间隔秒数；`0` 只检查一轮，有错误则退出码非零 |
| `RESTART_MAX` | `3` | 每个容器最多重启次数，恢复健康后清零 |
| `DOCKER_TIMEOUT` | `60` | 单条 docker 命令超时秒数，应大于容器停止加启动时间 |
| `CMD` | 空 | 通知命令，由 `sh -c` 执行，必须可信；镜像内含 `curl` |
| `CMD_TIMEOUT` | `30` | 单次 CMD 超时秒数 |
| `NOTIFY_EXITED` | `false` | `true` 时通知 exited 容器，见下文 |
| `TZ` | UTC | 时区 |

- 需挂载 Docker socket（或设置 `DOCKER_HOST`）；被检查容器需配置 healthcheck。
- 容器标签 `docker-health=false` 排除检查，本容器自身建议加上。
- 重启计数与 exited 记录保存在容器内 `/tmp`，本容器重启后清零（已 exited 的容器会再通知一次）。

## 行为

每轮：

1. 对 running 且 unhealthy 的容器：未达上限则先记次数再 `docker restart`（失败也计数），发送 `restart` 通知；达上限后不再处理。
2. 对有重启记录的容器：变为 running 且 healthy 时发送 `recovered` 通知并清零；容器已删除则丢弃记录；其他状态（starting 等）等待下一轮。
3. `NOTIFY_EXITED=true` 时，对 exited 容器（含人工停止）：不重启，只发送一次 `exited` 通知；重新 running 且 healthy（无 healthcheck 则 running 即可）时发送 `exited_recovered` 通知；仍为 unhealthy 时先走重启流程。

每轮每个容器最多一个事件。

日志（stdout）：

```text
<时间> event=restart container=<名> id=<短ID> attempt=<次数>/<上限> result=<success|failed|timeout>
<时间> event=recovered container=<名> id=<短ID> attempt=<次数>/<上限> downtime=<秒>s
<时间> event=exited container=<名> id=<短ID> exit_code=<退出码>
<时间> event=exited_recovered container=<名> id=<短ID> downtime=<秒>s
<时间> event=<事件> container=<名> cmd=success
<时间> event=<事件> container=<名> cmd=<failed|timeout> code=<退出码> output:
<CMD 完整输出>
```

CMD 输出被捕获，成功时不写入日志。

## 回调变量

下表为 restart / recovered；exited / exited_recovered 同样提供除重启字段外的变量，`DOWNTIME_SECONDS` 在 exited_recovered 中为发现退出到恢复的秒数。

| 变量 | restart | recovered | 说明 |
| --- | --- | --- | --- |
| `EVENT` | `restart` | `recovered` | 事件，另有 `exited` / `exited_recovered` |
| `EVENT_TIME` | ✓ | ✓ | 事件时间 |
| `MESSAGE` | ✓ | ✓ | 可直接发送的中文摘要 |
| `HOST_NAME` | ✓ | ✓ | Docker 主机名（`docker info`） |
| `CONTAINER_ID` / `CONTAINER_NAME` / `CONTAINER_IMAGE` | ✓ | ✓ | 容器完整 ID、名称、镜像 |
| `HEALTH_STATUS` | `unhealthy` | `healthy` | 当前健康状态 |
| `HEALTH_OUTPUT` | ✓ | ✓ | 最近一次健康检查输出（截断至 1000 字符） |
| `FAILING_STREAK` | ✓ | ✓ | 连续失败次数 |
| `RESTART_ATTEMPT` / `RESTART_MAX` | 本次是第几次 | 共重启次数 | 及上限 |
| `RESTART_RESULT` | `success` / `failed` / `timeout` | 空 | 本次重启结果 |
| `FIRST_RESTART_TIME` | ✓ | ✓ | 本轮故障首次重启时间 |
| `DOWNTIME_SECONDS` | 空 | ✓ | 首次重启到恢复的秒数 |
| `CONTAINER_STATUS` | ✓ | ✓ | 容器状态（running / exited 等） |
| `EXIT_CODE` | ✓ | ✓ | 容器最近一次退出码 |
| `EXITED_TIME` | 空 | 空 | exited / exited_recovered：发现退出的时间 |

示例（compose 中 `$$` 表示字面 `$`，`>-` 将多行折叠为一行；`curl -m` 应小于 `CMD_TIMEOUT`）：

```yaml
environment:
  CMD: >-
    curl -fsS -m 10
    --data-urlencode "subject=docker-health $$HOST_NAME $$CONTAINER_NAME $$EVENT"
    --data-urlencode "content=$$MESSAGE"
    http://127.0.0.1:8080/
```

`docker run` 中用单引号与单个 `$`：`-e CMD='curl -fsS -m 10 --data-urlencode "content=$MESSAGE" http://127.0.0.1:8080/'`。
