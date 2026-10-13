// 词汇闪测 · 学习数据同步 Worker（单用户，Bearer 密钥保护）。
//
// POST /v1/push  { table, rows: [...], updateExisting }  按 id 写入
// GET  /v1/pull?table=&since=&offset=&limit=           按 updated_at 增量读取
// GET  /v1/health                                       检查密钥与数据库

const TABLES = {
  review_events: { columns: ['id', 'word_id', 'created_at', 'payload'], updatable: false },
  exposure_events: { columns: ['id', 'word_id', 'local_date', 'payload'], updatable: false },
  test_runs: { columns: ['id', 'started_at', 'finished_at', 'payload'], updatable: true },
  // 用户标记按词覆盖，只接受更新的快照（后写者胜），设备推送先后不影响结果。
  word_flags: {
    columns: ['id', 'word_id', 'changed_at', 'payload'],
    updatable: true,
    newerOnly:
      'excluded.changed_at > word_flags.changed_at OR ' +
      '(excluded.changed_at = word_flags.changed_at AND excluded.payload > word_flags.payload)',
  },
};

const MAX_ROWS = 500;
const NOW = "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')";

export default {
  async fetch(request, env) {
    try {
      if (!env.SYNC_TOKEN || env.SYNC_TOKEN.length < 32) {
        return json({ error: 'server token not configured' }, 500);
      }
      if (!(await authorized(request, env.SYNC_TOKEN))) {
        return json({ error: 'unauthorized' }, 401);
      }
      const url = new URL(request.url);
      if (request.method === 'GET' && url.pathname === '/v1/health') {
        await env.DB.prepare('SELECT 1').first();
        return json({ ok: true });
      }
      if (request.method === 'POST' && url.pathname === '/v1/push') {
        return await push(await request.json(), env.DB);
      }
      if (request.method === 'GET' && url.pathname === '/v1/pull') {
        return await pull(url.searchParams, env.DB);
      }
      return json({ error: 'not found' }, 404);
    } catch (error) {
      return json({ error: String(error && error.message || error) }, 500);
    }
  },
};

async function push(body, db) {
  const spec = TABLES[body && body.table];
  if (!spec) return json({ error: 'unknown table' }, 400);
  const rows = Array.isArray(body.rows) ? body.rows : null;
  if (!rows || rows.length > MAX_ROWS) {
    return json({ error: `rows must be an array of at most ${MAX_ROWS}` }, 400);
  }
  const updateExisting = body.updateExisting === true && spec.updatable;
  const cols = spec.columns;
  const placeholders = cols.map(() => '?').join(', ');
  const onConflict = updateExisting
    ? `DO UPDATE SET ${cols.slice(1).map((c) => `${c} = excluded.${c}`).join(', ')}, updated_at = ${NOW}` +
      (spec.newerOnly ? ` WHERE ${spec.newerOnly}` : '')
    : 'DO NOTHING';
  const sql =
    `INSERT INTO ${body.table} (${cols.join(', ')}, updated_at) ` +
    `VALUES (${placeholders}, ${NOW}) ON CONFLICT(id) ${onConflict}`;
  const statements = [];
  for (const row of rows) {
    if (!row || typeof row.id !== 'string' || row.id.length === 0) {
      return json({ error: 'every row needs a string id' }, 400);
    }
    statements.push(
      db.prepare(sql).bind(
        ...cols.map((c) => (c === 'payload' ? JSON.stringify(row.payload) : row[c] ?? null)),
      ),
    );
  }
  if (statements.length > 0) await db.batch(statements);
  return json({ ok: true, rows: statements.length });
}

async function pull(params, db) {
  const table = params.get('table');
  if (!TABLES[table]) return json({ error: 'unknown table' }, 400);
  const since = params.get('since') || '';
  const offset = clampInt(params.get('offset'), 0, 0, 1e9);
  const limit = clampInt(params.get('limit'), 500, 1, MAX_ROWS);
  const { results } = await db
    .prepare(
      `SELECT payload, updated_at FROM ${table} WHERE updated_at > ? ` +
        'ORDER BY updated_at, id LIMIT ? OFFSET ?',
    )
    .bind(since, limit, offset)
    .all();
  return json({
    rows: results.map((r) => ({ payload: JSON.parse(r.payload), updated_at: r.updated_at })),
  });
}

async function authorized(request, token) {
  const header = request.headers.get('Authorization') || '';
  const given = header.startsWith('Bearer ') ? header.slice(7) : '';
  // 先做摘要再逐字节比较，长度不同也不提前返回，避免计时侧信道。
  const enc = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(given)),
    crypto.subtle.digest('SHA-256', enc.encode(token)),
  ]);
  const x = new Uint8Array(a);
  const y = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0 && given.length > 0;
}

function clampInt(value, fallback, min, max) {
  const n = Number.parseInt(value ?? '', 10);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : fallback;
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}
