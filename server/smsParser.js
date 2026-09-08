// Server-side port of lib/services/sms_parser.dart (Dart) 로직
//
// 목적: 아이폰 단축어가 "URL의 콘텐츠 가져오기(POST)" 액션으로 문자 원문을
// 서버에 직접 전송했을 때, Flutter 앱을 거치지 않고 서버에서 바로 파싱/분류하여
// - 확실한 경우: 거래내역에 즉시 자동 저장
// - 애매한 경우(식대 추정으로 공동사용자 선택 필요, 파싱 실패 등): 검토 대기(pending_sms)에 저장
// 할 수 있도록 한다. 정규식/판별 로직은 Dart 클라이언트 파서와 동일하게 유지한다.

const NON_APPROVAL_KEYWORDS = [
  '결제예정',
  '결제 예정',
  '출금예정',
  '출금 예정',
  '청구예정',
  '청구 예정',
  '이용대금',
  '명세서',
  '결제일',
  '연체',
  '자동이체',
  '카드대금',
];

const LUNCH_START_MIN = 11 * 60 + 30; // 11:30
const LUNCH_END_MIN = 14 * 60; // 14:00

const AMOUNT_LINE_RE = /^([0-9][0-9,]*)\s*원\s*(승인|취소|매출)$/;
const OVERSEAS_AMOUNT_LINE_RE =
  /^([A-Z]{2,3})\s+([0-9][0-9,]*\.?[0-9]*)\s*해외\s*(승인|취소|매출)$/;
const CARD_HOLDER_LINE_RE = /^(\S+)\s+([가-힣]{2,4})\s+(\S+)$/;
const DATE_TIME_RE = /(\d{1,2})[/.](\d{1,2})\D{1,4}(\d{1,2}):(\d{2})/;
const GENERIC_AMOUNT_RE = /([0-9][0-9,]*)\s*원/;

function isNonApprovalNotice(message) {
  const upper = message.toUpperCase();
  return NON_APPROVAL_KEYWORDS.some((kw) => upper.includes(kw.toUpperCase()));
}

function looksLikeCardApproval(message) {
  if (isNonApprovalNotice(message)) return false;
  const hasApprovalWord = message.includes('승인') || message.includes('매출');
  const hasKrwAmount = message.includes('원');
  const overseasLine = message
    .split('\n')
    .map((l) => l.trim())
    .find((l) => OVERSEAS_AMOUNT_LINE_RE.test(l));
  const hasOverseasAmount = !!overseasLine;
  return hasApprovalWord && (hasKrwAmount || hasOverseasAmount);
}

function parseAmount(raw) {
  if (raw == null) return null;
  const cleaned = String(raw).replace(/,/g, '');
  const v = parseFloat(cleaned);
  return Number.isNaN(v) ? null : v;
}

/// 문자 원문을 파싱. Dart의 SmsParser.parse()와 동일한 로직.
function parseSms(rawMessage) {
  if (isNonApprovalNotice(rawMessage)) {
    return {
      success: false,
      nonApprovalNotice: true,
      rejectReason: '카드 승인 문자가 아닌 결제(청구) 예정 안내 문자로 보입니다.',
    };
  }
  if (!looksLikeCardApproval(rawMessage)) {
    return {
      success: false,
      nonApprovalNotice: false,
      rejectReason: '카드 승인 문자 형식을 인식하지 못했습니다.',
    };
  }

  const lines = rawMessage
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l.length > 0)
    .filter((l) => !/^\[.*발신\]$/.test(l));

  let merchant = null;
  let amount = null;
  let currency = 'KRW';
  let dateTime = null;
  let cardHolder = null;
  let isOverseas = false;

  // 1) 해외승인 패턴 우선 시도
  let amountLineIndex = -1;
  for (let i = 0; i < lines.length; i++) {
    const m = OVERSEAS_AMOUNT_LINE_RE.exec(lines[i]);
    if (m) {
      currency = m[1] || 'USD';
      amount = parseAmount(m[2]);
      amountLineIndex = i;
      isOverseas = true;
      break;
    }
  }

  // 2) 국내 세로형 포맷
  if (amountLineIndex === -1) {
    for (let i = 0; i < lines.length; i++) {
      const m = AMOUNT_LINE_RE.exec(lines[i]);
      if (m) {
        amount = parseAmount(m[1]);
        amountLineIndex = i;
        currency = 'KRW';
        break;
      }
    }
  }

  if (amountLineIndex > 0) {
    const candidate = lines[amountLineIndex - 1];
    if (!DATE_TIME_RE.test(candidate) && !CARD_HOLDER_LINE_RE.test(candidate)) {
      merchant = candidate;
    }
  }

  // 3) 카드명의자 라인
  for (const line of lines) {
    const m = CARD_HOLDER_LINE_RE.exec(line);
    if (m) {
      cardHolder = m[2];
      break;
    }
  }

  // 4) 날짜/시간
  const dtMatch = DATE_TIME_RE.exec(rawMessage);
  if (dtMatch) {
    const month = parseInt(dtMatch[1], 10) || 1;
    const day = parseInt(dtMatch[2], 10) || 1;
    const hour = parseInt(dtMatch[3], 10) || 0;
    const minute = parseInt(dtMatch[4], 10) || 0;
    const now = new Date();
    const year = now.getFullYear();
    let candidate = new Date(year, month - 1, day, hour, minute);
    const oneDayLater = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    if (candidate.getTime() > oneDayLater.getTime()) {
      candidate = new Date(year - 1, month - 1, day, hour, minute);
    }
    dateTime = candidate;
  }

  // 5) 가로형 재시도
  if (amount == null) {
    for (const line of lines) {
      if (line.includes('누적')) continue;
      const m = GENERIC_AMOUNT_RE.exec(line);
      if (m) {
        amount = parseAmount(m[1]);
        currency = 'KRW';
        break;
      }
    }
  }

  if (!merchant) {
    for (const line of lines) {
      if (AMOUNT_LINE_RE.test(line)) continue;
      if (OVERSEAS_AMOUNT_LINE_RE.test(line)) continue;
      if (DATE_TIME_RE.test(line)) continue;
      if (CARD_HOLDER_LINE_RE.test(line)) continue;
      if (line.includes('누적')) continue;
      merchant = line;
      break;
    }
  }

  const success = amount != null && amount > 0;

  return {
    success,
    nonApprovalNotice: false,
    merchant,
    amount,
    currency,
    dateTime: dateTime || new Date(),
    cardHolder,
    isOverseas,
  };
}

function isLunchTime(dateTime) {
  const minutes = dateTime.getHours() * 60 + dateTime.getMinutes();
  return minutes >= LUNCH_START_MIN && minutes <= LUNCH_END_MIN;
}

/// mappingRules: [{keyword, detail, category}, ...] (DB row 형태 그대로 사용 가능)
function findMappingRule(merchant, rawMessage, rules, isOverseas) {
  const target = `${merchant || ''} ${rawMessage}`.toUpperCase();
  const trimmedMerchant = (merchant || '').trim().toUpperCase();
  for (const rule of rules) {
    if (!rule.keyword) continue;
    const keyword = String(rule.keyword).toUpperCase();
    if (target.includes(keyword)) return rule;
    if (isOverseas && trimmedMerchant && keyword.startsWith(trimmedMerchant)) {
      return rule;
    }
  }
  return null;
}

/// 자동 분류: 매핑규칙(해외 prefix 포함) > 식대(점심시간) > 기타
function classify({ dateTime, merchant, rawMessage, mappingRules, isOverseas }) {
  const rule = findMappingRule(merchant, rawMessage, mappingRules, isOverseas);
  if (rule) {
    return {
      category: rule.category,
      detail: rule.detail,
      isMealSuggested: false,
      matchedKeyword: rule.keyword,
    };
  }
  if (isLunchTime(dateTime)) {
    return { category: '식대', detail: '', isMealSuggested: true, matchedKeyword: null };
  }
  return { category: '기타', detail: '', isMealSuggested: false, matchedKeyword: null };
}

module.exports = {
  parseSms,
  classify,
  isNonApprovalNotice,
  looksLikeCardApproval,
  isLunchTime,
};
