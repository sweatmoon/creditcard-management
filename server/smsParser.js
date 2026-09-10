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

// 문자 원문의 날짜/시간은 항상 한국시간(KST, UTC+9) 기준으로 표기된다.
// 서버(Railway 등)는 시스템 시간대가 UTC인 경우가 많아, new Date(y,m,d,h,min)를
// 그대로 쓰면 "서버 로컬시간(=UTC)"로 잘못 해석되어 실제보다 9시간 어긋난 값이
// 저장되는 문제가 있었다. 항상 KST로 명시적으로 해석해서 UTC로 변환한다.
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

/// KST 기준의 연/월/일/시/분을 올바른 UTC Date 객체로 변환.
function kstDate(year, month, day, hour, minute) {
  // Date.UTC(...)는 "이 값들이 UTC다"라고 가정해 epoch ms를 만들어준다.
  // 여기서는 그 값들이 사실 KST이므로, KST->UTC 변환을 위해 9시간을 빼준다.
  const utcMs = Date.UTC(year, month - 1, day, hour, minute) - KST_OFFSET_MS;
  return new Date(utcMs);
}

/// 현재 시각을 KST 기준 {year, month(1-based), day, hour, minute}로 반환.
function nowKst() {
  const kstMs = Date.now() + KST_OFFSET_MS;
  const d = new Date(kstMs);
  return {
    year: d.getUTCFullYear(),
    month: d.getUTCMonth() + 1,
    day: d.getUTCDate(),
    hour: d.getUTCHours(),
    minute: d.getUTCMinutes(),
  };
}

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
  // 취소 문자("OO원 취소")도 개별 거래 문자이므로 승인/매출과 동일하게 인식해야
  // 한다. (그렇지 않으면 취소 문자가 파싱 실패로 처리되어 자동 저장되지 않음)
  const hasApprovalWord =
    message.includes('승인') || message.includes('매출') || message.includes('취소');
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
  // 문자에 명시된 동작(승인/취소/매출). "취소"인 경우 실제로는 카드사가
  // 수수료 등을 제외한 금액만 취소 처리하는 경우가 있어, 이 금액을 음수로
  // 저장해서 정산 합계에서 원거래와 자동으로 상계되도록 한다.
  let action = null;

  // 1) 해외승인 패턴 우선 시도
  let amountLineIndex = -1;
  for (let i = 0; i < lines.length; i++) {
    const m = OVERSEAS_AMOUNT_LINE_RE.exec(lines[i]);
    if (m) {
      currency = m[1] || 'USD';
      amount = parseAmount(m[2]);
      amountLineIndex = i;
      isOverseas = true;
      action = m[3] || null;
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
        action = m[2] || null;
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

  // 4) 날짜/시간 (문자 원문은 항상 한국시간(KST) 기준 표기이므로 KST로 해석)
  const dtMatch = DATE_TIME_RE.exec(rawMessage);
  if (dtMatch) {
    const month = parseInt(dtMatch[1], 10) || 1;
    const day = parseInt(dtMatch[2], 10) || 1;
    const hour = parseInt(dtMatch[3], 10) || 0;
    const minute = parseInt(dtMatch[4], 10) || 0;
    const nowK = nowKst();
    const year = nowK.year;
    let candidate = kstDate(year, month, day, hour, minute);
    const oneDayLater = new Date(Date.now() + 24 * 60 * 60 * 1000);
    if (candidate.getTime() > oneDayLater.getTime()) {
      candidate = kstDate(year - 1, month, day, hour, minute);
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

  const isCancellation = action === '취소';
  // 취소 문자는 금액을 음수로 바꿔서, 정산 합계 시 원거래(양수)와 자동으로
  // 상계되도록 한다. (전액환불이 아닌 수수료 차감 취소도 정확히 반영됨)
  if (isCancellation && amount != null) {
    amount = -Math.abs(amount);
  }

  const success = amount != null && amount !== 0;

  return {
    success,
    nonApprovalNotice: false,
    merchant,
    amount,
    currency,
    dateTime: dateTime || new Date(),
    cardHolder,
    isOverseas,
    isCancellation,
  };
}

function isLunchTime(dateTime) {
  // dateTime은 UTC epoch를 담은 Date 객체이므로, 서버 시스템 시간대와 무관하게
  // 항상 KST 기준 시/분으로 변환해서 판별해야 한다. (getHours()는 서버 로컬
  // 시간대를 쓰기 때문에 UTC 서버에서는 9시간 어긋난 결과가 나온다.)
  const kstMs = dateTime.getTime() + KST_OFFSET_MS;
  const kst = new Date(kstMs);
  const minutes = kst.getUTCHours() * 60 + kst.getUTCMinutes();
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

/// 상세내용 앞에 "[취소]" 태그를 붙인다(중복 방지).
function withCancelTag(detail, isCancellation) {
  if (!isCancellation) return detail || '';
  const base = detail || '';
  if (base.startsWith('[취소]')) return base;
  return base ? `[취소] ${base}` : '[취소]';
}

/// 자동 분류: 매핑규칙(해외 prefix 포함) > 식대(점심시간) > 기타
/// isCancellation이 true면 계정과목은 원거래와 동일하게 유지하되, 상세내용에
/// "[취소]" 태그를 붙여 목록에서 바로 구분되도록 한다. (금액은 이미 parseSms
/// 단계에서 음수로 변환됨)
function classify({
  dateTime,
  merchant,
  rawMessage,
  mappingRules,
  isOverseas,
  isCancellation = false,
}) {
  const rule = findMappingRule(merchant, rawMessage, mappingRules, isOverseas);
  if (rule) {
    return {
      category: rule.category,
      detail: withCancelTag(rule.detail, isCancellation),
      isMealSuggested: false,
      matchedKeyword: rule.keyword,
    };
  }
  if (!isCancellation && isLunchTime(dateTime)) {
    return { category: '식대', detail: '', isMealSuggested: true, matchedKeyword: null };
  }
  return {
    category: '기타',
    detail: withCancelTag('', isCancellation),
    isMealSuggested: false,
    matchedKeyword: null,
  };
}

module.exports = {
  parseSms,
  classify,
  isNonApprovalNotice,
  looksLikeCardApproval,
  isLunchTime,
};
