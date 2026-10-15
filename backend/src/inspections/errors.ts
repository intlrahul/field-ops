export class DomainError extends Error {
  constructor(public statusCode: number, public code: string, message: string, public details?: { blockers: { code: string; itemId: string }[] }) { super(message); }
}
export function supervisor(role: string): void {
  if (role !== 'supervisor') throw new DomainError(403,'FORBIDDEN','Supervisor access required');
}
export function notFound(): never { throw new DomainError(404,'NOT_FOUND','Resource not found'); }
