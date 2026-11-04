# rdap

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/qvgz/rdap)

WHOIS/RDAP 查询域名注册信息及到期时间。脚本构建时取自上游 [qvgz/sh ops/rdap.sh](https://github.com/qvgz/sh/blob/master/ops/rdap.sh)，说明见 [rdap.sh.md](https://github.com/qvgz/sh/blob/master/ops/rdap.sh.md)。示例见 [compose.yaml](./compose.yaml)。

```bash
docker run --rm qvgz/rdap example.com
docker run --rm qvgz/rdap -v https://www.example.com/
# 批量：当前目录需有 rdap.sh.txt，报告写回当前目录
docker run --rm -u "$(id -u):$(id -g)" -e TZ=Asia/Shanghai -v "$PWD:/data" qvgz/rdap -d
docker run --rm -u "$(id -u):$(id -g)" -e TZ=Asia/Shanghai -v "$PWD:/data" qvgz/rdap -f domains.txt -d 30
```

## 与上游的差异

- 默认清单为 `/data/rdap.sh.txt`（上游为脚本同目录），工作目录 `/data`，相对路径的 `-f` 清单与报告均在此目录。
- 镜像内含 whois，WHOIS 优先、RDAP 兜底。

## 变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `RDAP_QUERY_INTERVAL` | `3` | 批量查询间隔秒数，支持非负小数 |
| `TZ` | UTC | 时区，影响剩余天数计算 |

- 批量需挂载清单所在目录到 `/data`，且容器用户对其可写；`-u` 使报告属主与宿主用户一致。
- 报告文件由 `mktemp` 生成后原子替换，权限为 `600`。
- 任一域名查询失败返回非零。

## 用法

- 单域名接受域名、子域名或 HTTP(S) URL；默认输出 expiration、last changed、registration、首个 nameservers，`-v` 输出 WHOIS 原文或 RDAP JSON。
- `-f [清单]` 批量：每行首列为输入，忽略空行和 `#` 注释；生成 `清单.check.txt`（输入、到期日、剩余天数，失败为 `X` 置顶，其余按天数升序）。
- `-d [天数]` 默认 30，另生成 `清单.check.Nd.txt`，保留剩余天数 ≤ N（含已过期）及 `X`；单独 `-d` 使用默认清单。
- 根域名按最后两级提取，仅 ac.cn/com.cn/edu.cn/gov.cn/net.cn/org.cn 保留三级；IDN 需使用 Punycode。
