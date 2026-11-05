# log-clean

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/qvgz/log-clean)

一次性任务：备份目录顶层 `.log` 文件，压缩复制到 `backup/昨日YYYYMMDD/` 后清空原文件，执行可选重开命令，删除过期备份。脚本构建时取自上游 [qvgz/sh ops/log-clean.sh](https://github.com/qvgz/sh/blob/master/ops/log-clean.sh)，说明见 [log-clean.sh.md](https://github.com/qvgz/sh/blob/master/ops/log-clean.sh.md)。

```bash
# 用法：[-k 保留天数，默认 90] [-t 只清空不备份] 日志目录 [重开命令]
docker run --rm -v /var/log/nginx:/logs qvgz/log-clean /logs
docker run --rm -v /var/log/myapp:/logs qvgz/log-clean -k 30 /logs
docker run --rm -v /var/log/debug:/logs qvgz/log-clean -t /logs   # 只清空，不留备份
```

## 示例

宿主机 crontab，每日 0 点后执行：

```cron
5 0 * * * docker run --rm -v /var/log/nginx:/logs qvgz/log-clean /logs >>/var/log/log-clean.err 2>&1
```

多个目录：

```bash
for d in /var/log/nginx /data/app/logs; do
  docker run --rm -v "$d:/logs" qvgz/log-clean -k 30 /logs || echo "失败：$d" >&2
done
```

普通用户目录，备份属主与宿主用户一致：

```bash
docker run --rm -u "$(id -u):$(id -g)" -v "$HOME/app/logs:/logs" qvgz/log-clean /logs
```

重开命令在本容器内执行，需共享目标进程的 PID 命名空间才能发信号：

```bash
# 目标为容器：其 PID 1 即主进程
docker run --rm --pid container:myapp -v /data/myapp/logs:/logs qvgz/log-clean /logs 'kill -HUP 1'
# 目标为宿主机进程：挂载 pid 文件（以 root 运行）
docker run --rm --pid host -v /run/myapp.pid:/run/myapp.pid:ro -v /var/log/myapp:/logs \
  qvgz/log-clean /logs 'kill -HUP "$(cat /run/myapp.pid)"'
```

## 说明

- 镜像 `TZ` 默认 `Asia/Shanghai`（上游按此计算昨日日期），可用 `-e TZ=` 覆盖。
- 容器用户须对日志目录可写；挂载的是日志目录本身，`backup/` 与锁文件 `.log-clean.lock` 生成在其中。
- 写入进程须以追加模式（O_APPEND）打开日志（如 nginx、shell `>>`），否则需配置重开命令；采集端须支持文件被清空后从头读。
- 退出码：参数错误或目录不存在 `2`，锁冲突或压缩失败 `1`，重开命令失败返回其退出码。
- 压缩、清空及过期删除不自动回退；过期按 `backup/YYYYMMDD` 目录整个删除，勿在其中存放其他文件。
