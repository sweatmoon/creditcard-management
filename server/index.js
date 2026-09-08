// Smart SMS Ledger - API 서버 + Flutter Web 정적 파일 서빙 (Railway 배포용)
//
// 구조:
//   - /api/*  : Postgres 기반 REST API (거래내역 / 팀원 / 매핑규칙)
//   - 그 외    : Flutter Web 빌드 결과(build/web) 정적 서빙 (SPA 폴백 포함)
//
// Railway는 컨테이너에 동적 $PORT를 주입하므로 반드시 process.env.PORT를 사용해야 함.
const path = require('path');
const express = require('express');
const cors = require('cors');
const { pool, initSchema } = require('./db');

const app = express();
app.use(cors());
app.use(express.json());

// 로컬 개발: repo의 build/web을 직접 서빙 (별도 복사 불필요)
// Docker 배포: Dockerfile에서 STATIC_DIR=/app/public 으로 지정, build/web을 복사해 사용
const STATIC_DIR =
  process.env.STATIC_DIR || path.join(__dirname, '..', 'build', 'web');

// ---------------------------------------------------------------------------
// Transactions
// ---------------------------------------------------------------------------

function rowToTransaction(row) {
  return {
    id: row.id,
    merchant: row.merchant,
    amount: Number(row.amount),
    currency: row.currency,
    category: row.category,
    detail: row.detail,
    coUsers: row.co_users || [],
    dateTime: row.date_time,
    cardHolder: row.card_holder,
    rawMessage: row.raw_message,
    createdAt: row.created_at,
  };
}

app.get('/api/transactions', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM transactions ORDER BY date_time DESC',
    );
    res.json(rows.map(rowToTransaction));
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

app.post('/api/transactions', async (req, res) => {
  try {
    const t = req.body;
    await pool.query(
      `INSERT INTO transactions
        (id, merchant, amount, currency, category, detail, co_users, date_time, card_holder, raw_message, created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       ON CONFLICT (id) DO UPDATE SET
        merchant=$2, amount=$3, currency=$4, category=$5, detail=$6,
        co_users=$7, date_time=$8, card_holder=$9, raw_message=$10`,
      [
        t.id,
        t.merchant,
        t.amount,
        t.currency || 'KRW',
        t.category || '기타',
        t.detail || '',
        JSON.stringify(t.coUsers || []),
        t.dateTime,
        t.cardHolder || null,
        t.rawMessage || '',
        t.createdAt || new Date().toISOString(),
      ],
    );
    res.status(201).json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to save transaction' });
  }
});

app.put('/api/transactions/:id', async (req, res) => {
  try {
    const t = req.body;
    await pool.query(
      `UPDATE transactions SET
        merchant=$2, amount=$3, currency=$4, category=$5, detail=$6,
        co_users=$7, date_time=$8, card_holder=$9, raw_message=$10
       WHERE id=$1`,
      [
        req.params.id,
        t.merchant,
        t.amount,
        t.currency || 'KRW',
        t.category || '기타',
        t.detail || '',
        JSON.stringify(t.coUsers || []),
        t.dateTime,
        t.cardHolder || null,
        t.rawMessage || '',
      ],
    );
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to update transaction' });
  }
});

app.delete('/api/transactions/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM transactions WHERE id=$1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to delete transaction' });
  }
});

// ---------------------------------------------------------------------------
// Team members (공동사용자)
// ---------------------------------------------------------------------------

app.get('/api/team-members', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT name FROM team_members ORDER BY created_at ASC',
    );
    res.json(rows.map((r) => r.name));
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to fetch team members' });
  }
});

app.post('/api/team-members', async (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'name is required' });
    }
    await pool.query(
      'INSERT INTO team_members (name) VALUES ($1) ON CONFLICT (name) DO NOTHING',
      [name.trim()],
    );
    res.status(201).json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to add team member' });
  }
});

app.delete('/api/team-members/:name', async (req, res) => {
  try {
    await pool.query('DELETE FROM team_members WHERE name=$1', [
      req.params.name,
    ]);
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to remove team member' });
  }
});

// ---------------------------------------------------------------------------
// Mapping rules (자동 매핑 규칙)
// ---------------------------------------------------------------------------

app.get('/api/mapping-rules', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, keyword, detail, category FROM mapping_rules ORDER BY id ASC',
    );
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to fetch mapping rules' });
  }
});

app.post('/api/mapping-rules', async (req, res) => {
  try {
    const { keyword, detail, category } = req.body;
    const { rows } = await pool.query(
      'INSERT INTO mapping_rules (keyword, detail, category) VALUES ($1,$2,$3) RETURNING id',
      [keyword, detail || '', category || '기타'],
    );
    res.status(201).json({ ok: true, id: rows[0].id });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to add mapping rule' });
  }
});

app.put('/api/mapping-rules/:id', async (req, res) => {
  try {
    const { keyword, detail, category } = req.body;
    await pool.query(
      'UPDATE mapping_rules SET keyword=$2, detail=$3, category=$4 WHERE id=$1',
      [req.params.id, keyword, detail || '', category || '기타'],
    );
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to update mapping rule' });
  }
});

app.delete('/api/mapping-rules/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM mapping_rules WHERE id=$1', [
      req.params.id,
    ]);
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to delete mapping rule' });
  }
});

// ---------------------------------------------------------------------------
// Health check
// ---------------------------------------------------------------------------

app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true, db: 'connected' });
  } catch (e) {
    res.status(500).json({ ok: false, db: 'disconnected', error: String(e) });
  }
});

// ---------------------------------------------------------------------------
// Flutter Web 정적 파일 서빙 (SPA 폴백)
// ---------------------------------------------------------------------------

app.use(express.static(STATIC_DIR));

app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api/')) return next();
  res.sendFile(path.join(STATIC_DIR, 'index.html'));
});

const PORT = process.env.PORT || 8080;

initSchema()
  .then(() => {
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Smart SMS Ledger server listening on port ${PORT}`);
    });
  })
  .catch((e) => {
    console.error('Failed to initialize DB schema:', e);
    process.exit(1);
  });
