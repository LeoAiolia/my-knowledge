# cc-docker：自定义 AI 开发 Docker 环境

> **路径**：`/Users/run/Desktop/cc-docker`
> **更新日期**：2026-07-02

## 项目简介

`cc-docker` 是一个自定义 Docker 环境，为 AI 辅助开发（Claude Code / Codex）提供隔离、可复用的运行容器。核心思路：将 AI CLI 工具运行在 Docker 中，通过 tun2socks 透明代理解决网络访问问题，通过 Redis 实现团队配置共享。

## 整体架构

```
┌─────────────────────────────────────────────────────┐
│  Docker Compose                                      │
│                                                      │
│  ┌──────────┐  共享网络   ┌───────────────────────┐  │
│  │  proxy   │◄──────────►│  cli (业务容器)         │  │
│  │tun2socks │            │  registry.../ai/cli    │  │
│  └────┬─────┘            │  /projects → 宿主机代码 │  │
│       │                  │  /home/node → 持久化    │  │
│  ┌────┴─────┐            └───────────────────────┘  │
│  │   dns    │                                       │
│  │ dnsproxy │                                       │
│  └──────────┘                                       │
└─────────────────────────────────────────────────────┘
```

### 三层服务

| 服务 | 镜像 | 作用 |
|---|---|---|
| `proxy` | `xjasonlyu/tun2socks` | 透明代理，创建虚拟网卡接管容器内所有流量 |
| `dns` | `adguard/dnsproxy` | 加密 DNS（TCP 上游），防止路由器 DNS 劫持 |
| `cli` | `registry.dev.yuxiaor.cn/ai/cli:latest` | 业务容器，运行 Claude Code / Codex 等 AI 工具 |

### 网络流路径

```
cli 容器流量 → 共享 proxy 网络栈 → tun2socks 虚拟网卡 → SOCKS5 代理 → 外网
                                    ↑
                              DNS 查询走 dnsproxy
                              (tcp://8.8.8.8:53)
```

## 核心配置说明

### 1. 网络代理（proxy + dns）

- `proxy` 通过 `TUN_EXCLUDED_ROUTES` 排除局域网地址（`192.168.0.0/16, 10.10.0.0/16`），本地服务直连不走代理。
- `dns` 强制使用 TCP 上游 DNS（Google `8.8.8.8` + Cloudflare `1.1.1.1`），避免路由器劫持 DNS 导致污染。
- `extra_hosts` 硬编码内部服务地址：
  - `model.ai.yuxiaor.com` → 内网 AI 模型服务
  - `nexus.dev.yuxiaor.cn` → 内网 Docker Registry
  - `claude.ai` / `platform.claude.com` → `127.0.0.1`（阻断直连，强制走代理）

### 2. 业务容器（cli）

- **镜像**：`registry.dev.yuxiaor.cn/ai/cli:latest`（内部定制镜像，基于 Linux amd64）
- **权限**：`SYS_ADMIN` + `SYS_PTRACE` + `NET_ADMIN`（bubblewrap 沙箱隔离所需）
- **环境变量**（关键项）：

| 变量 | 说明 |
|---|---|
| `ANTHROPIC_BASE_URL` | Claude API 代理地址，默认 `http://localhost:8030/` |
| `CONFIG_SYNC_REDIS_HOST` | Redis 地址，用于团队配置同步 |
| `SYNC_GROUP_ROLE` | 同步角色 `leader` / `follower` |
| `SYNC_GROUP_MEMBER_NAME` | 成员标识，用于用量统计和分组 |
| `CLI_CONTAINER_NAME` | 容器名，同一宿主机多实例时必须不同 |
| `CLAUDE_CONFIG_DIR` | Claude 配置目录，通过环境隔离支持多实例 |
| `CLI_ENV_DIR` | 环境根目录，格式 `/home/node/env-{容器名}` |

### 3. 挂载卷

| 宿主机路径 | 容器路径 | 说明 |
|---|---|---|
| `./data/home` | `/home/node` | 持久化用户目录（配置、凭证、Shell 历史） |
| `/Users/run/Documents/yxr` | `/projects` | 项目代码（读写） |
| `/Users/run/.ssh` | `/home/node/.ssh` | SSH 密钥（只读） |

### 4. Shell 环境（`.yxrrc`）

容器内同时支持 zsh 和 bash，公共配置写在 `~/.yxrrc` 中：

- **Flutter 镜像**：使用国内镜像源（`pub.flutter-io.cn`）
- **快捷别名**：`cda` → 跳转 aster 项目、`cdr` → 跳转 faraday_reborn
- **远程控制**：`claudetg` 命令带 Telegram channel 启动，支持远程操作
- **Starship 提示符**：zsh 下使用 starship 美化终端

## 团队共享机制

通过 Redis 实现 Claude Code 配置和 Token 的跨容器同步：

- **组长（leader）**：将自己的配置和 Token 上传到 Redis
- **组员（follower）**：从 Redis 拉取组长的配置，保持同步
- **分组依据**：`HOSTNAME:MACHINE_ID` 作为组 ID
- **用量平衡**：根据 `SYNC_GROUP_MEMBER_NAME` 统计各成员用量，平衡分组

> 当前配置：角色 `follower`，成员 `csr`，组 ID 为 `ai-dev-pc1:b3cb66...`

## 当前版本的文件结构

```
cc-docker/
├── .env                    # 环境变量（代理、用户、同步配置）
├── .env.cli2               # 第二个 cli 实例的备用配置
├── docker-compose.yml      # 服务编排（proxy + dns + cli）
├── .gitignore              # 忽略 data/home 中的敏感/缓存文件
├── .claude/                # Claude Code 本地设置
│   └── settings.local.json
└── data/
    └── home/               # 持久化的用户主目录
        ├── .yxrrc          # Shell 公共配置
        ├── .zshrc          # Zsh 配置（oh-my-zsh + starship）
        ├── .bashrc         # Bash 配置
        ├── .config/starship.toml
        ├── bin/codex       # Codex wrapper
        └── env-cli/        # 第一个实例的环境数据
```

## 常用操作

```bash
# 启动
cd /Users/run/Desktop/cc-docker
docker compose up -d

# 进入容器
docker exec -it cli zsh

# 查看日志
docker compose logs -f cli

# 重启
docker compose restart cli

# 停止
docker compose down
```

## 常见问题

### `Error: Claude native binary not installed`

在容器内运行 `claude` 时报此错误，说明 CLI 原生二进制未安装或版本过旧。执行以下命令更新：

```bash
update-clis
```

该命令会拉取并安装最新的 Claude Code CLI 二进制，完成后即可正常使用。
