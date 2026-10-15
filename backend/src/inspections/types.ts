export type Actor = { id: string; role: 'supervisor' | 'technician' };
export type AssetInput = { assetTag: string; name: string; location?: string | null };
export type AssetSnapshot = { id: string; assetTag: string; name: string; location: string | null };
export type Asset = AssetSnapshot & { createdAt: string; updatedAt: string; version: number };
export type ChecklistDefinition = { label: string; required: boolean };
export type ReadingDefinition = ChecklistDefinition & { unit: string; minValue: number | null; maxValue: number | null };
export type InspectionInput = {
  assetId: string; assigneeId: string; title: string; dueAt?: string | null;
  checklistItems: ChecklistDefinition[]; readingDefinitions: ReadingDefinition[];
};
export type InspectionSummary = {
  id: string; title: string; status: 'assigned' | 'in_progress' | 'completed';
  asset: AssetSnapshot; assigneeId: string; dueAt: string | null;
  createdAt: string; updatedAt: string; version: number;
};
export type ChecklistItem = ChecklistDefinition & { id: string; position: number; result: 'pass' | 'fail' | null; failureNote: string | null };
export type Reading = ReadingDefinition & { id: string; position: number; value: number | null; rangeStatus: 'unrecorded' | 'in_range' | 'out_of_range' };
export type InspectionDetail = InspectionSummary & {
  checklistItems: ChecklistItem[]; readings: Reading[]; notes: InspectionNote[];
  startedAt: string | null; completedAt: string | null;
};
export type ListQuery = { limit?: string; cursor?: string; status?: InspectionSummary['status']; assetId?: string; assigneeId?: string };
export type PagePosition = { createdAt: string; id: string };
export type ListOptions = { limit: number; position?: PagePosition; status?: string; assetId?: string; assigneeId?: string };

export type InspectionNote = { id: string; authorId: string; text: string; createdAt: string };
export type ChecklistResultInput = { result: 'pass' | 'fail' | null; failureNote?: string | null };
