import type { Req } from '../types'

type RawReq = { requestId: string; status: string; updatedAt?: string; autoApplyAfter?: string; failure?: { stage?: string; summary?: string } }

export const ACTIVE = new Set(['pending_confirmation', 'requested', 'rendering', 'rendered', 'planning', 'planned', 'approval_wait', 'shared_approval_wait', 'approved', 'applying'])
const FAILED = new Set(['failed', 'rejected', 'expired', 'partial_apply', 'rolled_back'])

export function toReqs(stdout: string): Req[] | null {
  try {
    const out = JSON.parse(stdout)
    if (out?.ok !== true) return null
    return (out.items ?? []).map((r: RawReq) => ({
      id: r.requestId,
      status: r.status,
      failure: r.failure ? `${r.failure.stage ?? ''}: ${r.failure.summary ?? ''}` : '',
      autoApplyAfter: r.autoApplyAfter ?? null,
      updatedAt: r.updatedAt ?? '',
    }))
  } catch {
    return null
  }
}

// approval_wait with autoApplyAfter needs no human: the policy applies it at that time.
export const statusKey = (r: Req): string => (r.status === 'approval_wait' && r.autoApplyAfter ? 'auto_apply_scheduled' : r.status)

const hhmm = (iso: string) => {
  const d = new Date(iso)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

export function label(r: Req, now: number): string {
  switch (statusKey(r)) {
    case 'applied': return '✓ 적용 완료'
    case 'partial_apply': return '⚠ 일부 실패'
    case 'rolled_back': return '↩ 롤백됨'
    case 'failed': return '✕ 실패'
    case 'rejected': return '✕ 거절됨'
    case 'expired': return '✕ 만료됨'
    case 'cancelled': return '■ 취소됨'
    case 'superseded': return '↪ 새 요청으로 대체'
    case 'pending_confirmation': return '● 확인 필요'
    case 'approval_wait': return '● 승인 필요'
    case 'auto_apply_scheduled': return Date.parse(r.autoApplyAfter!) <= now ? '◷ 곧 자동 적용' : `◷ 자동 승인 예정 ${hhmm(r.autoApplyAfter!)}`
    case 'shared_approval_wait': return '● 공유 리소스 승인 대기'
    case 'approved': return '✓ 승인됨'
    default: return '◷ 진행 중'
  }
}

export type Tone = 'success' | 'error' | 'warning' | 'suggestion' | 'inactive'
export function tone(r: Req): Tone {
  const k = statusKey(r)
  if (k === 'applied' || k === 'approved') return 'success'
  if (FAILED.has(k)) return 'error'
  if (k === 'pending_confirmation' || k === 'approval_wait' || k === 'shared_approval_wait') return 'warning'
  if (ACTIVE.has(k) || k === 'auto_apply_scheduled') return 'suggestion'
  return 'inactive'
}

// The 5 stages of skills/arona-status: 확인 · 준비 · 검사·plan · 승인 · 적용.
export function stage(status: string): number {
  if (status === 'pending_confirmation') return 1
  if (['requested', 'rendering', 'rendered'].includes(status)) return 2
  if (['planning', 'planned'].includes(status)) return 3
  if (['approval_wait', 'shared_approval_wait', 'approved'].includes(status)) return 4
  return 5
}
export const dots = (status: string) => '●'.repeat(stage(status)) + '○'.repeat(5 - stage(status))

// What the person must do, if anything.
export function action(r: Req): string {
  const k = statusKey(r)
  if (k === 'pending_confirmation') return `wikk confirm ${r.id}`
  if (k === 'approval_wait') return `wikk approve ${r.id}`
  if (k === 'shared_approval_wait') return '웹 「공유 리소스 승인」'
  return ''
}

// One toast line for a new or changed request, or null; prev is the last seen status key (undefined = new).
export function transition(prev: string | undefined, r: Req, now: number): string | null {
  const k = statusKey(r)
  if (prev === k) return null
  const todo = action(r)
  return `ARONA ${r.id.slice(0, 8)} ${label(r, now)} (${prev ?? 'new'} → ${k})${r.failure ? ` · ${r.failure}` : ''}${todo ? ` → ${todo}` : ''}`
}

const SHOW_ACTIVE_MS = 24 * 3600_000
const SHOW_DONE_MS = 10 * 60_000

// Band rows: requests still moving (touched within a day), and ones that just ended (10 minutes).
export function isShown(r: Req, now: number, changedAt: number | undefined): boolean {
  const k = statusKey(r)
  if (!r.failure && (ACTIVE.has(k) || k === 'auto_apply_scheduled')) return now - Date.parse(r.updatedAt) < SHOW_ACTIVE_MS
  return changedAt !== undefined && now - changedAt < SHOW_DONE_MS
}
