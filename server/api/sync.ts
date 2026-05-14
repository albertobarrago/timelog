import type { VercelRequest, VercelResponse } from '@vercel/node'
import { getDb, checkApiKey } from './_db'
import { ObjectId } from 'mongodb'

interface ClientDTO   { _id: string; name: string; colorHex: string; isArchived: boolean }
interface ProjectDTO  { _id: string; name: string; code?: string; isArchived: boolean; clientMongoId?: string }
interface EntryDTO    { _id: string; date: string; durationMinutes: number; notes?: string; clientMongoId?: string; projectMongoId?: string }

interface SyncPayload {
  clients:  ClientDTO[]
  projects: ProjectDTO[]
  entries:  EntryDTO[]
}

// POST /api/sync — bulk upsert all collections
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (!checkApiKey(req)) return res.status(401).json({ error: 'Unauthorized' })
  if (req.method !== 'POST') return res.status(405).end()

  const { clients, projects, entries } = req.body as SyncPayload
  const db = await getDb()

  const toOid = (id: string) => ObjectId.isValid(id) ? new ObjectId(id) : new ObjectId()

  await Promise.all([
    ...clients.map(c =>
      db.collection('clients').updateOne(
        { _id: toOid(c._id) },
        { $set: { name: c.name, colorHex: c.colorHex, isArchived: c.isArchived } },
        { upsert: true }
      )
    ),
    ...projects.map(p =>
      db.collection('projects').updateOne(
        { _id: toOid(p._id) },
        { $set: { name: p.name, code: p.code, isArchived: p.isArchived, clientMongoId: p.clientMongoId } },
        { upsert: true }
      )
    ),
    ...entries.map(e =>
      db.collection('time_entries').updateOne(
        { _id: toOid(e._id) },
        { $set: { date: new Date(e.date), durationMinutes: e.durationMinutes, notes: e.notes, clientMongoId: e.clientMongoId, projectMongoId: e.projectMongoId } },
        { upsert: true }
      )
    ),
  ])

  res.json({ ok: true })
}
