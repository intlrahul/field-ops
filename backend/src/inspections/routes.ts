import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { authService } from '../auth/service.js';
import type { SqliteDatabase } from '../db/database.js';
import { workflowRoutes } from './workflow-routes.js';
import { httpSchemas } from './http-schemas.js';
import { supervisor } from './errors.js';
import { inspectionService } from './service.js';
import type { Actor, AssetInput, InspectionInput, ListQuery } from './types.js';

declare module 'fastify' { interface FastifyRequest { fieldOpsActor: Actor | null } }
const uuid = { type: 'string',format: 'uuid' };
const idParams = { type: 'object', required: ['id'],additionalProperties: false,properties: { id: uuid } };
const commonQuery = {
  limit: { type: 'string',pattern: '^[0-9]{1,3}$' },
  cursor: { type: 'string',minLength: 1,maxLength: 2048 },
};
const response = (name: string) => ({ $ref: `domain.${name}#` });
const actor = (request: FastifyRequest) => request.fieldOpsActor!;
const trimKeys = new Set(['name','location','assetTag','title','label','unit','failureNote','text']);
function trimText(value: unknown): void {
  if (Array.isArray(value)) { for (const item of value) trimText(item); }
  else if (value !== null && typeof value === 'object') {
    for (const [key,item] of Object.entries(value)) {
      if (trimKeys.has(key) && typeof item === 'string') (value as Record<string,unknown>)[key] = item.trim();
      else if (key === 'checklistItems' || key === 'readingDefinitions') trimText(item);
    }
  }
}
export async function inspectionRoutes(app: FastifyInstance, db: SqliteDatabase, auth: ReturnType<typeof authService>, now?: () => number) {
  const service = inspectionService(db,now);
  for (const schema of Object.values(httpSchemas)) app.addSchema(schema);
  app.decorateRequest('fieldOpsActor',null);
  app.addHook('onRequest',async req => { req.fieldOpsActor = (await auth.authenticate(req.headers.authorization)).user; });
  app.addHook('preValidation',async req => { trimText(req.body); });
  app.addHook('onSend',async (_req,reply) => { reply.header('Cache-Control','no-store'); });
  const supervisorOnly = async (req: FastifyRequest) => { supervisor(actor(req).role); };
  app.post<{ Body: AssetInput }>('/assets',{
    onRequest: supervisorOnly, schema: { body: response('AssetCreate'), response: { 201: response('Asset') } },
  },async (req,reply) => {
    const asset = service.createAsset(actor(req),req.body);
    return reply.code(201).header('Location',`/assets/${asset.id}`).send(asset);
  });
  app.get<{ Querystring: ListQuery }>('/assets',{
    onRequest: supervisorOnly, schema: {
      querystring: { type: 'object',additionalProperties: false,properties: commonQuery },
      response: { 200: response('AssetPage') },
    },
  },async req => service.listAssets(actor(req),req.query));
  app.get<{ Params: { id: string } }>('/assets/:id',{
    schema: { params: idParams,response: { 200: response('Asset') } },
  },async req => service.getAsset(actor(req),req.params.id));
  app.post<{ Body: InspectionInput }>('/inspections',{
    onRequest: supervisorOnly, schema: { body: response('InspectionCreate'),response: { 201: response('InspectionDetail') } },
  },async (req,reply) => {
    const inspection = service.createInspection(actor(req),req.body);
    return reply.code(201).header('Location',`/inspections/${inspection.id}`).send(inspection);
  });
  app.get<{ Querystring: ListQuery }>('/inspections',{
    schema: {
      querystring: { type: 'object',additionalProperties: false,properties: {
        ...commonQuery, status: { type: 'string',enum: ['assigned','in_progress','completed'] },assetId: uuid,assigneeId: uuid,
      } }, response: { 200: response('InspectionSummaryPage') },
    },
  },async req => service.listInspections(actor(req),req.query));
  app.get<{ Params: { id: string } }>('/inspections/:id',{
    schema: { params: idParams,response: { 200: response('InspectionDetail') } },
  },async req => service.getInspection(actor(req),req.params.id));
  await workflowRoutes(app,db,now);
}
