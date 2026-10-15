import type { ChecklistItem, Reading, ReadingDefinition } from './types.js';
export type CompletionBlocker = { code: 'CHECKLIST_UNANSWERED' | 'FAILURE_NOTE_REQUIRED' | 'READING_REQUIRED' | 'READING_INVALID' | 'READING_OUT_OF_RANGE'; itemId: string };
export function readingStatus(value: number | null, bounds: Pick<ReadingDefinition,'minValue' | 'maxValue'>): Reading['rangeStatus'] {
  if (value === null) return 'unrecorded';
  return !Number.isFinite(value) || (bounds.minValue !== null && value < bounds.minValue)
    || (bounds.maxValue !== null && value > bounds.maxValue) ? 'out_of_range' : 'in_range';
}
export function completionBlockers(checks: Pick<ChecklistItem,'id' | 'required' | 'result' | 'failureNote'>[], readings: Pick<Reading,'id' | 'required' | 'value' | 'minValue' | 'maxValue'>[]): CompletionBlocker[] {
  const blockers: CompletionBlocker[] = [];
  for (const item of checks) {
    if (item.required && item.result === null) blockers.push({ code: 'CHECKLIST_UNANSWERED',itemId: item.id });
    if (item.result === 'fail' && !item.failureNote?.trim()) blockers.push({ code: 'FAILURE_NOTE_REQUIRED',itemId: item.id });
  }
  for (const item of readings) {
    if (item.value === null) {
      if (item.required) blockers.push({ code: 'READING_REQUIRED',itemId: item.id });
    } else if (!Number.isFinite(item.value)) blockers.push({ code: 'READING_INVALID',itemId: item.id });
    else if (readingStatus(item.value,item) === 'out_of_range') blockers.push({ code: 'READING_OUT_OF_RANGE',itemId: item.id });
  }
  return blockers;
}
