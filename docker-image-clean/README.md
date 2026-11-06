# docker-image-clean

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/qvgz/docker-image-clean)

一次性任务：每个仓库保留最近 N 个不同镜像（默认 5），删除超额标签并清理悬空镜像；容器（含已停止）引用的镜像不删。脚本构建时取自上游 [qvgz/sh containers/docker-image-clean.sh](https://github.com/qvgz/sh/blob/master/containers/docker-image-clean.sh)，说明见 [docker-image-clean.sh.md](https://github.com/qvgz/sh/blob/master/containers/docker-image-clean.sh.md)。

```bash
# 用法：[--dry-run] [保留镜像数，默认 5]
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock qvgz/docker-image-clean --dry-run 10  # 只列出，不删除
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock qvgz/docker-image-clean               # 每个仓库保留 5 个
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock qvgz/docker-image-clean 10            # 每个仓库保留 10 个
```

## 示例

宿主机 crontab，每周日 3 点执行：

```cron
0 3 * * 0 docker run --rm -v /var/run/docker.sock:/var/run/docker.sock qvgz/docker-image-clean 10 >>/var/log/docker-image-clean.log 2>&1
```

## 说明

- 需挂载 Docker socket（或设置 `DOCKER_HOST`）。
- 清理全部悬空镜像，不强制删除；执行前确认镜像可重新拉取或构建。
- “最近”指镜像创建时间，不是拉取时间；旧构建新拉取的镜像仍排在后面。
- 同 ID 多标签只占一个名额；被容器引用的镜像占名额且不删除。本容器运行时引用自身镜像，不会删除自身。
- 退出码：参数错误 `2`，查询容器或镜像失败时不做删除并返回非零；任一删除或清理失败返回非零，不中断后续删除。
