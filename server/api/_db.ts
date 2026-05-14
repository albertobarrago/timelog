import { MongoClient, Db } from 'mongodb'

let client: MongoClient | null = null

export async function getDb(): Promise<Db> {
  if (!client) {
    client = new MongoClient(process.env.MONGODB_URI!)
    await client.connect()
  }
  return client.db()
}

export function checkApiKey(req: { headers: { [key: string]: string | string[] | undefined } }): boolean {
  const key = req.headers['x-api-key']
  return key === process.env.API_KEY
}
