# 闲鱼自动回复系统 - Docker 部署说明

本项目已在当前目录使用 Docker Compose 部署，采用作者发布的阿里云预构建镜像（无需在本地编译前端/后端）。

## 访问地址

| 服务 | 地址 |
| --- | --- |
| 主界面 | http://localhost:9000 |
| API 文档 | http://localhost:8089/docs |
| Backend-Web 健康检查 | http://localhost:8089/health |
| WebSocket | http://localhost:8090 |
| Scheduler | http://localhost:8091 |

默认管理员：`admin` / `admin123`。**首次登录后请立即修改密码。**

## 常用命令

在 PowerShell 中进入本目录后执行：

```powershell
# 首次部署或更新镜像并启动
.\deploy.ps1

# 仅使用本地已有镜像启动
.\deploy.ps1 -SkipPull

# 查看状态
docker compose -f docker-compose.deploy.yml --env-file .env ps

# 查看全部日志
docker compose -f docker-compose.deploy.yml --env-file .env logs -f

# 查看单个服务日志
docker compose -f docker-compose.deploy.yml --env-file .env logs -f backend-web

# 重启 / 停止 / 启动
docker compose -f docker-compose.deploy.yml --env-file .env restart
docker compose -f docker-compose.deploy.yml --env-file .env down
docker compose -f docker-compose.deploy.yml --env-file .env up -d
```

> 若 PowerShell 提示禁止运行脚本，可仅对本次执行放行：
> `powershell -ExecutionPolicy Bypass -File .\deploy.ps1`

## 配置文件

- `.env`：端口、数据库/Redis 密码、镜像标签等。首次部署已生成随机强密码；修改后执行 `docker compose ... up -d` 使配置生效。
- `docker-compose.deploy.yml`：预构建镜像的完整编排（MySQL、Redis、Backend-Web、WebSocket、Scheduler、Frontend）。
- 数据目录：`xianyu_auto_reply/`
  - `mysql/data`：MySQL 数据
  - `redis/data`：Redis AOF 数据
  - `logs/`：三个后端服务的日志
  - `static/`：上传的图片、二维码等静态文件
  - `backups/`：应用备份
  - `browser_data`：Playwright 浏览器数据

## 商品账号串号补丁

当前部署额外挂载了两个本地补丁，避免鱼小铺子账号/共享浏览器 Cookie 把 A 店铺商品写进 B 账号：

- `common/services/item_service.py`：鱼小铺列表返回的卖家 ID 与当前账号不一致时，改用个人版接口按当前账号重新抓取，禁止跨账号入库。
- `common/utils/cookie_refresh.py`：Cookie 回写前校验 `unb`，拒绝把其他账号的 Cookie 写入当前账号。

两个文件以只读方式挂载到 `backend-web`、`websocket`、`scheduler`，更新镜像后补丁仍然生效。若后续上游已修复该问题，可移除 `docker-compose.deploy.yml` 中对应的挂载。

## 更新

```powershell
.\deploy.ps1
```

脚本会拉取 `latest` 镜像，然后执行 `up -d --remove-orphans`，数据目录和 `.env` 不受影响。

## 注意事项

- 容器重启策略为 `unless-stopped`，Docker Desktop 启动后会自动拉起。
- 首次启动会自动建表并初始化数据；MySQL 初始化通常需要 1~3 分钟，请等待健康检查变为 `healthy`。
- 本机 8GB 内存下同时运行 6 个容器，建议在 Docker Desktop 中分配至少 6GB 内存。
- MySQL 与 Redis 未映射到宿主机端口，仅应用端口对外暴露。
- 若更改端口，请同时检查防火墙与 `FRONTEND_PUBLIC_URL` 等对外地址配置。
- 生产环境建议在 `9000` 端口前增加 HTTPS 反向代理，并限制 `CORS_ORIGINS`。
