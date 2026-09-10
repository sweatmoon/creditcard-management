// Smart SMS Ledger - API 서버 + Flutter Web 정적 파일 서빙 (Railway 배포용)
//
// 구조:
//   - /api/*  : Postgres 기반 REST API (거래내역 / 팀원 / 매핑규칙)
//   - 그 외    : Flutter Web 빌드 결과(build/web) 정적 서빙 (SPA 폴백 포함)
//
// Railway는 컨테이너에 동적 $PORT를 주입하므로 반드시 process.env.PORT를 사용해야 함.
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const { pool, initSchema } = require('./db');
const smsParser = require('./smsParser');

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
// SMS 자동 수집 (아이폰 단축어 "URL의 콘텐츠 가져오기" POST 액션용)
//
// Safari/앱 화면을 전혀 띄우지 않고, 단축어가 문자 원문을 이 엔드포인트로
// 바로 전송한다. 서버가 즉시 파싱/분류하여:
//   - 파싱 성공 -> 식대 여부와 무관하게 항상 transactions 테이블에 바로
//     자동 저장한다 (식대로 추정된 경우도 공동사용자 확인 없이 co_users를
//     빈 배열로 두고 즉시 저장, 필요하면 나중에 상세화면에서 직접 수정).
//   - 파싱 실패(원문에서 금액/가맹점을 못 찾은 경우)만
//     -> pending_sms(검토 대기) 테이블에 저장, 앱에서 나중에 확인 후 처리
// ---------------------------------------------------------------------------

function rowToPending(row) {
  return {
    id: row.id,
    rawMessage: row.raw_message,
    merchant: row.merchant,
    amount: row.amount != null ? Number(row.amount) : null,
    currency: row.currency,
    dateTime: row.date_time,
    cardHolder: row.card_holder,
    category: row.category,
    detail: row.detail,
    isMealSuggested: row.is_meal_suggested,
    parseSuccess: row.parse_success,
    rejectReason: row.reject_reason,
    status: row.status,
    createdAt: row.created_at,
  };
}

app.post('/api/sms/ingest', async (req, res) => {
  try {
    const rawMessage = (req.body && req.body.text) || (req.body && req.body.rawMessage) || '';
    if (!rawMessage || !rawMessage.trim()) {
      return res.status(400).json({ error: 'text is required' });
    }

    const parsed = smsParser.parseSms(rawMessage);

    if (!parsed.success) {
      // 파싱 실패(안내성 문자 포함) -> 검토 대기로 저장, 확인용으로만 남김
      await pool.query(
        `INSERT INTO pending_sms
          (raw_message, merchant, amount, currency, date_time, card_holder, category, detail, is_meal_suggested, parse_success, reject_reason, status)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'pending')`,
        [
          rawMessage,
          null,
          null,
          'KRW',
          null,
          null,
          '기타',
          '',
          false,
          false,
          parsed.rejectReason || null,
        ],
      );
      return res.status(200).json({
        ok: true,
        autoSaved: false,
        reason: parsed.rejectReason || '파싱 실패',
      });
    }

    // 매핑 규칙 조회 후 분류 (자동 사용처 교정 포함)
    const { rows: ruleRows } = await pool.query(
      'SELECT id, keyword, detail, category FROM mapping_rules ORDER BY id ASC',
    );
    const classification = smsParser.classify({
      dateTime: parsed.dateTime,
      merchant: parsed.merchant || '알 수 없음',
      rawMessage,
      mappingRules: ruleRows,
      isOverseas: parsed.isOverseas,
      isCancellation: parsed.isCancellation,
    });
    const merchant = classification.matchedKeyword
      ? classification.matchedKeyword
      : parsed.merchant || '알 수 없음';

    // 파싱에 성공했다면 식대 추정 여부와 무관하게 항상 즉시 자동 저장한다.
    // (공동사용자는 비워두고 저장, 필요시 앱에서 상세화면을 열어 나중에 채워넣으면 됨)
    const id = crypto.randomUUID();
    const now = new Date().toISOString();
    await pool.query(
      `INSERT INTO transactions
        (id, merchant, amount, currency, category, detail, co_users, date_time, card_holder, raw_message, created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [
        id,
        merchant,
        parsed.amount,
        parsed.currency,
        classification.category,
        classification.detail,
        JSON.stringify([]),
        parsed.dateTime,
        parsed.cardHolder || null,
        rawMessage,
        now,
      ],
    );

    return res.status(201).json({ ok: true, autoSaved: true, id });
  } catch (e) {
    console.error('sms ingest error:', e);
    res.status(500).json({ error: 'Failed to process sms' });
  }
});

// 검토 대기 목록 조회 (status=pending인 것만 기본)
app.get('/api/pending-sms', async (req, res) => {
  try {
    const status = req.query.status || 'pending';
    const { rows } = await pool.query(
      'SELECT * FROM pending_sms WHERE status=$1 ORDER BY created_at DESC',
      [status],
    );
    res.json(rows.map(rowToPending));
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to fetch pending sms' });
  }
});

// 검토 대기 항목을 실제 거래로 승인(저장) 처리 -> transactions에 삽입 후 pending 상태 변경
// 요청 본문(body)의 값으로 사용자가 앱에서 수정한 내용(사용처/금액/계정과목/공동사용자 등)을
// 덮어쓸 수 있으며, 원본 문자(raw_message)는 pending_sms 레코드에서 그대로 가져온다.
app.post('/api/pending-sms/:id/approve', async (req, res) => {
  try {
    const { rows: pendingRows } = await pool.query(
      'SELECT * FROM pending_sms WHERE id=$1',
      [req.params.id],
    );
    if (pendingRows.length === 0) {
      return res.status(404).json({ error: 'pending sms not found' });
    }
    const pending = pendingRows[0];
    const t = req.body || {}; // 사용자가 확인/수정한 값 (없으면 pending 값 사용)

    const id = crypto.randomUUID();
    const now = new Date().toISOString();
    await pool.query(
      `INSERT INTO transactions
        (id, merchant, amount, currency, category, detail, co_users, date_time, card_holder, raw_message, created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [
        id,
        t.merchant || pending.merchant,
        t.amount != null ? t.amount : pending.amount,
        t.currency || pending.currency || 'KRW',
        t.category || pending.category || '기타',
        t.detail != null ? t.detail : pending.detail || '',
        JSON.stringify(t.coUsers || []),
        t.dateTime || pending.date_time,
        t.cardHolder || pending.card_holder || null,
        pending.raw_message,
        now,
      ],
    );
    await pool.query(
      "UPDATE pending_sms SET status='approved' WHERE id=$1",
      [req.params.id],
    );
    res.status(201).json({ ok: true, id });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to approve pending sms' });
  }
});

// 검토 대기 항목을 거부(무시) 처리
app.post('/api/pending-sms/:id/reject', async (req, res) => {
  try {
    await pool.query(
      "UPDATE pending_sms SET status='rejected' WHERE id=$1",
      [req.params.id],
    );
    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Failed to reject pending sms' });
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
