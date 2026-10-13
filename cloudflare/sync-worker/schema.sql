-- 学习数据同步（单用户）。只追加的学习事实；卡片状态由各设备按事件在本地重算。
-- updated_at 由服务端写入，客户端按它增量拉取。

CREATE TABLE IF NOT EXISTS review_events (
  id TEXT PRIMARY KEY,
  word_id INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS exposure_events (
  id TEXT PRIMARY KEY,
  word_id INTEGER NOT NULL,
  local_date TEXT NOT NULL,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS test_runs (
  id TEXT PRIMARY KEY,
  started_at TEXT NOT NULL,
  finished_at TEXT,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS review_events_pull ON review_events (updated_at, id);
CREATE INDEX IF NOT EXISTS exposure_events_pull ON exposure_events (updated_at, id);
CREATE INDEX IF NOT EXISTS test_runs_pull ON test_runs (updated_at, id);
