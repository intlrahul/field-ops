export class DomainError extends Error {
  constructor(public statusCode: number, public code: string, message: string, public details?: { blockers: { code: string; itemId: string }[] }) { super(message); }
}
export function notFound(): never { throw new DomainError(404,'NOT_FOUND','Resource not found'); }
