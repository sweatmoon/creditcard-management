// PostgreSQL 연결 및 스키마 초기화
//
// Railway에 Postgres 플러그인을 추가하면 자동으로 DATABASE_URL 환경변수가
// 주입됩니다. 로컬 개발 시에는 .env 또는 아래 기본값(로컬 postgres)을 사용합니다.
const { Pool } = require('pg');

const connectionString =
  process.env.DATABASE_URL ||
  'postgresql://postgres:localdevpass@localhost:5432/smart_sms_ledger';

// Railway의 관리형 Postgres는 대부분 SSL이 필요 없는 내부 네트워크로 연결되지만,
// 외부(Public) 연결 URL을 쓰는 경우 SSL이 필요할 수 있어 옵션으로 처리합니다.
const useSsl = process.env.PGSSL === 'true';

const pool = new Pool({
  connectionString,
  ssl: useSsl ? { rejectUnauthorized: false } : false,
});

async function initSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY,
      merchant TEXT NOT NULL,
      amount NUMERIC NOT NULL,
      currency TEXT NOT NULL DEFAULT 'KRW',
      category TEXT NOT NULL DEFAULT '기타',
      detail TEXT NOT NULL DEFAULT '',
      co_users JSONB NOT NULL DEFAULT '[]',
      date_time TIMESTAMPTZ NOT NULL,
      card_holder TEXT,
      raw_message TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS team_members (
      name TEXT PRIMARY KEY,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS mapping_rules (
      id SERIAL PRIMARY KEY,
      keyword TEXT NOT NULL,
      detail TEXT NOT NULL DEFAULT '',
      category TEXT NOT NULL DEFAULT '기타',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  // 최초 배포 시 기본 매핑 규칙이 비어있으면 시드 데이터 삽입
  const { rows } = await pool.query('SELECT COUNT(*)::int AS cnt FROM mapping_rules');
  if (rows[0].cnt === 0) {
    const defaults = [
      ['GENSPARK.AI', 'AI 서비스 구독료', '기타'],
      ['RAILWAY', '서버 호스팅비', '기타'],
      ['ANTHROPIC', 'AI API 사용료', '기타'],
    ];
    for (const [keyword, detail, category] of defaults) {
      await pool.query(
        'INSERT INTO mapping_rules (keyword, detail, category) VALUES ($1, $2, $3)',
        [keyword, detail, category],
      );
    }
  }
}

module.exports = { pool, initSchema };
