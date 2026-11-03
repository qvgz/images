# docker-health

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/qvgz/docker-health)

常驻容器，定时检查宿主机上 running 且 unhealthy 的容器并重启，记录恢复事件，可配置回调。示例见 [compose.yaml](./compose.yaml)。

```bash
docker run -d --name docker-health --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e TZ=Asia/Shanghai -l docker-health=false qvgz/docker-health
```

## 变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `INTERVAL` | `60` | 检查间隔秒数；`0` 仅检查一轮并以本轮结果退出 |
| `DOCKER_TIMEOUT` | `60` | 单条 docker 命令超时秒数，应大于容器停止等待时间加启动时间 |
| `CMD` | 空 | 事件回调，由 `sh -c` 执行，必须可信；镜像内含 `curl` |
| `TZ` | UTC | 日志时区 |
| `HEALTH_STATE_DIR` | `/tmp/docker-health-state` | 重启计数目录 |
| `HEALTH_LOG_FILE` | `/dev/stdout` | 事件日志 |

- 需挂载 Docker socket（或设置 `DOCKER_HOST`）；被检查容器需配置 healthcheck。
- 容器标签 `docker-health=false` 可排除检查，本容器自身建议加上。
- 状态不持久化：本容器重启后重启计数清零。
- 超时只终止 CLI，Daemon 端的重启可能仍在进行；日志或回调失败不会撤销已完成的重启。

## 行为

- 每轮一次查询取所有 running 且 unhealthy 的容器；退出由 restart 策略（如 `unless-stopped`）负责，人工停止的容器不处理。
  - 先记录次数，再执行 docker restart；每个容器最多尝试 3 次，失败也计数。
- 遍历重启记录做恢复检查：容器 running 且 healthy 时记录 recovered、删除记录并执行回调；容器已删除则删除记录。
- 启动时检查 docker 可用（`docker version` 能连上 Daemon），不可用即退出。
- 运行中 ps、inspect 超时只记录并通知 timeout 事件；连续超时跨轮计数，超过 3 次只记日志不再回调。之后任一 docker 命令有响应即记录并通知 docker_recovered，计数清零。
- restart 超时多为容器停止慢，只记为重启结果 timeout，不计入上述超时。
- 日志格式：
  - 重启：`<时间> container=<名> attempt=<次数> result=<success|failed|timeout> status="unhealthy"`
  - 恢复：`<时间> container=<名> event=recovered status="healthy"`
  - 超时：`<时间> container=<名> id=<ID> event=timeout command="<命令>" count=<连续次数>`
  - docker 恢复：`<时间> event=docker_recovered timeouts=<此前连续超时次数>`
- 回调环境：`CONTAINER_NAME`、`CONTAINER_ID`、`CONTAINER_STATUS`、`CONTAINER_EVENT`（restart/recovered/timeout/docker_recovered）、`EVENT_TIME`、`RESTART_TIME`、`RESTART_ATTEMPT`、`RESTART_RESULT`、`RECOVERY_TIME`，timeout 事件另有 `DOCKER_COMMAND`；不适用字段置空，恢复次数为 0。
- `INTERVAL=0` 时退出码：检测到 unhealthy 即非零（即使重启成功）；检查、状态写入、日志或回调失败也非零。
