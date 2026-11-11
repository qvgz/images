# ssl-check

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/qvgz/ssl-check)

HTTPS/SSL/TLS 证书信息及到期时间。脚本构建时取自上游 [qvgz/sh ops/ssl-check.sh](https://github.com/qvgz/sh/blob/master/ops/ssl-check.sh)，说明见 [ssl-check.sh.md](https://github.com/qvgz/sh/blob/master/ops/ssl-check.sh.md)。示例见 [compose.yaml](./compose.yaml)。

```bash
docker run --rm qvgz/ssl-check example.com
docker run --rm qvgz/ssl-check -v example.com
# 批量：当前目录需有 ssl-check.sh.txt，报告写回当前目录
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/data" qvgz/ssl-check -d
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/data" qvgz/ssl-check -f domains.txt -d 30
```

## 与上游的差异

- 默认清单为 `/data/ssl-check.sh.txt`（上游为脚本同目录），工作目录 `/data`，相对路径的 `-f` 清单与报告均在此目录。

## 变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SSL_CHECK_QUERY_INTERVAL` | `1` | 批量查询间隔秒数，支持非负小数 |

- 日期与剩余天数固定按 Asia/Shanghai 计算，`TZ` 不影响结果。
- 批量需挂载清单所在目录到 `/data`，且容器用户对其可写；`-u` 使报告属主与宿主用户一致。
- 报告文件由 `mktemp` 生成后原子替换，权限为 `600`。
- 任一域名查询失败返回非零。

## 用法

- 单域名以 SNI 连接 443，输出 issuer、subject、notBefore、notAfter，`-v` 输出证书全文；仅读取叶证书，不验证信任链或主机名。
- 输入为主机名，不接受 URL 或自定义端口；连接限时 10 秒，不自动重试。
- `-f [清单]` 批量：每行首列为域名，忽略空行和 `#` 注释；生成 `清单.check.txt`（域名、到期日、剩余天数，失败为 `X` 置顶，其余按天数升序），同次运行重复域名不重复查询。
- `-d [天数]` 默认 30，另生成 `清单.check.Nd.txt`，保留剩余天数 ≤ N（含已过期）及 `X`；单独 `-d` 使用默认清单。
