import { expect, test } from 'vitest';
import { completionBlockers, readingStatus } from '../src/inspections/rules.js';

const check = { id: 'check',required: true,result: null,failureNote: null } as const;
const reading = { id: 'reading',required: true,value: null,minValue: 0,maxValue: 80 };

test('collects all missing requirements and distinguishes unexplained failures', () => {
  expect(completionBlockers([check,{ ...check,id: 'failure',result: 'fail',failureNote: '  ' }],[reading]))
    .toEqual([
      { code: 'CHECKLIST_UNANSWERED',itemId: 'check' },
      { code: 'FAILURE_NOTE_REQUIRED',itemId: 'failure' },
      { code: 'READING_REQUIRED',itemId: 'reading' },
    ]);
});

test('explained failures allow completion and unanswered optional items are allowed', () => {
  expect(completionBlockers([{ ...check,result: 'fail',failureNote: 'Cracked housing reported' },
    { ...check,id: 'optional',required: false }],[{ ...reading,value: 80 },{ ...reading,id: 'optional',required: false }]))
    .toEqual([]);
});

test('a provided optional out-of-range reading and an optional unexplained failure block completion', () => {
  expect(completionBlockers([{ ...check,required: false,result: 'fail' }],[{ ...reading,required: false,value: 90 }]))
    .toEqual([{ code: 'FAILURE_NOTE_REQUIRED',itemId: 'check' },{ code: 'READING_OUT_OF_RANGE',itemId: 'reading' }]);
});

test.each([
  [null,0,80,'unrecorded'],[0,0,80,'in_range'],[80,0,80,'in_range'],[-0.01,0,80,'out_of_range'],
  [80.01,0,80,'out_of_range'],[-100,null,null,'in_range'],[81,null,80,'out_of_range'],[-1,0,null,'out_of_range'],
] as const)('range classification of %s with [%s,%s]',(value,minValue,maxValue,expected) => {
  expect(readingStatus(value,{ minValue,maxValue })).toBe(expected);
});

test.each([NaN,Infinity,-Infinity])('invalid numeric values cannot satisfy required readings: %s',value => {
  expect(completionBlockers([],[{ ...reading,value }])).toEqual([{ code: 'READING_INVALID',itemId: 'reading' }]);
});
