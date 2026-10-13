# 学习数据同步 Worker

手机和平板通过这个 Cloudflare Worker 同步学习记录。单用户，用一个随机的同步密钥保护；数据存在 Cloudflare D1（免费额度足够）。

同步的只有只追加的学习事实：作答事件、新词首次接触、测试轮次。卡片状态不上传，各设备收到新记录后按事件历史在本地重算。设置和 AI 接口密钥不上传。

## 部署（只需一次）

在本目录下执行：

```sh
# 1. 登录 Cloudflare（会打开浏览器）
npx wrangler login

# 2. 创建数据库，把输出里的 database_id 填进 wrangler.toml
npx wrangler d1 create vocab-flash-sync

# 3. 建表
npx wrangler d1 execute vocab-flash-sync --remote --file schema.sql

# 4. 生成并设置同步密钥（记下这串字符，两台设备都要填）
openssl rand -hex 32
npx wrangler secret put SYNC_TOKEN

# 5. 部署，输出里的 https://vocab-flash-sync.<你的子域>.workers.dev 就是 Worker 地址
npx wrangler deploy
```

然后在两台设备的「设置 → 云同步」里填同样的 Worker 地址和同步密钥。

## 接口

所有请求都要带 `Authorization: Bearer <SYNC_TOKEN>`，否则返回 401。

- `GET /v1/health`：检查密钥与数据库。
- `POST /v1/push`：`{ table, rows, updateExisting }`，按 `id` 写入。作答事件和接触记录已存在时忽略；只有 `test_runs` 允许覆盖（轮次完成后会再传一次）。每次最多 500 行。
- `GET /v1/pull?table=&since=&offset=&limit=`：按服务端 `updated_at` 增量读取。

`table` 只接受 `review_events`、`exposure_events`、`test_runs`。

## 本地测试

```sh
printf 'SYNC_TOKEN=%s\n' "$(openssl rand -hex 32)" > .dev.vars
npx wrangler d1 execute vocab-flash-sync --local --file schema.sql
npx wrangler dev --local
```

在项目根目录运行端到端测试（两个真实 SQLite 设备通过 HTTP 互相同步）：

```sh
SYNC_E2E_URL=http://127.0.0.1:8787 SYNC_E2E_TOKEN=<.dev.vars 里的密钥> \
  flutter test test/cloud_sync_test.dart
```

## 换密钥

密钥泄露时重新执行 `npx wrangler secret put SYNC_TOKEN`，再在两台设备上断开同步、填新密钥重新连接。数据不受影响。
