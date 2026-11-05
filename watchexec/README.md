# watchexec

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/qvgz/watchexec)

包装 [watchexec](https://github.com/watchexec/watchexec)（构建时取上游 release 二进制）：`WATCH` 中的路径变更后执行 `CMD`。示例见 [compose.yaml](./compose.yaml)。

```bash
docker run -d --name watchexec --restart unless-stopped \
  -v /etc/dae:/dae:ro -v /var/run/docker.sock:/var/run/docker.sock \
  -e WATCH=/dae -e DEBOUNCE=60 -e CMD='docker exec dae dae reload' qvgz/watchexec
```

## 变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `WATCH` | 必填 | 监听的目录或文件，多个用空白分隔（不支持含空格的路径）；目录递归监听 |
| `CMD` | 必填 | 变更后执行的命令，由 `bash -c` 执行；镜像内含 `curl`、`docker` |
| `DEBOUNCE` | `1` | 合并窗口，纯数字为秒，也可写 `500ms`、`1min 30s` |
| `IGNORE` | 空 | 追加忽略的文件或目录，多个用空白分隔，见[过滤](#过滤) |
| `CMD_TIMEOUT` | `60` | `CMD` 超时秒数，`0` 不限；超时先 TERM，5 秒后 KILL |
| `FAIL_CMD` | 空 | `CMD` 失败或超时时执行的通知命令，变量见下文 |
| `FAIL_CMD_TIMEOUT` | `60` | `FAIL_CMD` 超时秒数，`0` 不限 |
| `TZ` | `Asia/Shanghai` | 日志时区 |

容器参数（compose 的 `command`）原样作为 watchexec 选项，如 `--poll 2s` 用于 NFS 等不支持 inotify 的挂载，见 `watchexec --help`。

## 过滤

始终忽略 `.DS_Store`（含子目录）。`IGNORE` 追加忽略规则，gitignore 语法，不展开通配：

| 规则 | 忽略 |
| --- | --- |
| `*.swp` / `*~` | 任意层级匹配的文件，如编辑器临时文件 |
| `cache` | 任意层级名为 cache 的文件或目录（`cache/**` 无效） |
| `logs/` | 任意层级名为 logs 的目录 |

```yaml
IGNORE: "*.swp *~ cache logs/"
```

只监听部分文件用容器参数：`-e conf,yaml` 按扩展名，`-f '*.conf'` 按通配，可与 `IGNORE` 组合：

```yaml
command: ["-e", "dae"]
```

## 行为

- 自首个变更起 `DEBOUNCE` 内的所有变更合并，窗口结束时执行一次；窗口不因后续变更顺延。如 `DEBOUNCE=60`，12:00:00 起 60 秒内变更 100 次，只在 12:01:00 执行一次。
- 同一时间只运行一个 `CMD`；运行中再有变更，结束后补执行一次。
- 启动时不执行。
- 除 `.DS_Store` 与 `IGNORE` 外不过滤，编辑器临时文件（`.swp`、`~`）同样触发，见[过滤](#过滤)。
- 监听单个文件时，编辑器以替换方式保存（`sed -i`、`mv`）仍可触发；同目录其他文件不触发。

## 日志

`CMD` 输出被捕获，成功只记一行，失败或超时附完整输出（stdout 与 stderr 合并）：

```text
2026-11-05T12:00:00+0800 start watch=/dae debounce=60s ignore=.DS_Store *.swp cmd_timeout=60s
2026-11-05T12:01:00+0800 cmd=success duration=73ms
2026-11-05T12:05:00+0800 cmd=failed code=1 duration=10ms output:
<完整输出>
2026-11-05T12:05:00+0800 fail_cmd=success duration=120ms
2026-11-05T12:09:00+0800 cmd=timeout code=124 duration=60010ms output:
<超时前输出>
```

## FAIL_CMD 变量

| 变量 | 说明 |
| --- | --- |
| `EXIT_CODE` | `CMD` 退出码 |
| `OUTPUT` | `CMD` 输出（截断至 1000 字符） |
| `MESSAGE` | 摘要：`watchexec <WATCH> 变更后执行命令失败，退出码 <码>` |
| `WATCH` / `CMD` | 原变量 |

compose 中用 `$$` 表示字面 `$`；`docker run` 中用单引号：`-e FAIL_CMD='curl -fsS -m 10 --data-urlencode "content=$MESSAGE" http://127.0.0.1:8080/'`。
