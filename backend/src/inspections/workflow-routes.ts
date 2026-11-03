import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { SqliteDatabase } from '../db/database.js';
import { requireCapability } from '../authorization/policy.js';
import { DomainError } from './errors.js';
import { workflowService } from './workflow-service.js';
import type { ChecklistResultInput } from './types.js';

const ref = (name: string) => ({ $ref: `domain.${name}#` });
const uuid = { type: 'string',format: 'uuid' };
function params(child?: string) {
  return { type: 'object',additionalProperties: false,required: ['id',...(child ? [child] : [])],
    properties: { id: uuid,...(child ? { [child]: uuid } : {}) } };
}
async function emptyBody(req: FastifyRequest) {
  if (req.body !== undefined && (req.body === null || typeof req.body !== 'object'
    || Array.isArray(req.body) || Object.keys(req.body).length > 0)) {
    throw new DomainError(400,'INVALID_REQUEST','This operation accepts only an empty body');
  }
}
export async function workflowRoutes(app: FastifyInstance, db: SqliteDatabase, now?: () => number) {
  const service = workflowService(db,now);
  const actor = (req: FastifyRequest) => req.fieldOpsActor!;
  const performerOnly = async (req: FastifyRequest) => {
    requireCapability(actor(req),'inspections.perform');
  };
  for (const action of ['start','complete'] as const) {
    app.post<{ Params: { id: string } }>(`/inspections/:id/${action}`,{
      onRequest: performerOnly,preValidation: emptyBody,
      schema: { params: params(),response: { 200: ref('InspectionDetail') } },
    },async req => service[action](actor(req),req.params.id));
  }
  app.put<{ Params: { id: string; itemId: string }; Body: ChecklistResultInput }>('/inspections/:id/checklist-items/:itemId/result',{
    onRequest: performerOnly,
    schema: { params: params('itemId'),body: ref('ChecklistResultInput'),response: { 200: ref('InspectionDetail') } },
  },async req => service.result(actor(req),req.params.id,req.params.itemId,req.body));
  app.put<{ Params: { id: string; readingId: string }; Body: { value: number } }>('/inspections/:id/readings/:readingId',{
    onRequest: performerOnly,
    schema: { params: params('readingId'),body: ref('ReadingValueInput'),response: { 200: ref('InspectionDetail') } },
  },async req => service.reading(actor(req),req.params.id,req.params.readingId,req.body.value));
  app.post<{ Params: { id: string }; Body: { text: string } }>('/inspections/:id/notes',{
    onRequest: performerOnly,
    schema: { params: params(),body: ref('NoteInput'),response: { 201: ref('Note') } },
  },async (req,reply) => reply.code(201).send(service.note(actor(req),req.params.id,req.body.text)));
}
