# Sync Server Setup — new machine notes

## 1. Local configuration file

Create the file `~/.config/timelog/sync.local` with this content:

```bash
mkdir -p ~/.config/timelog

cat > ~/.config/timelog/sync.local << 'EOF'
URL=https://timelog-server.vercel.app
API_KEY=YOUR_API_KEY
EOF

chmod 600 ~/.config/timelog/sync.local
```

> Replace `YOUR_API_KEY` with the key you set on Vercel.

The app reads this file on first launch and saves the credentials to Keychain automatically.
No manual input in Settings required.

## 2. Vercel environment variables (already set — for reference only)

The `timelog-server` project on Vercel has these configured:
- `MONGODB_URI` — MongoDB Atlas connection string
- `API_KEY` — secret key shared with the app

To retrieve them: run `vercel env pull` from the `server/` folder.

## 3. Quick verification

```bash
curl -s -H "X-API-Key: YOUR_API_KEY" https://timelog-server.vercel.app/api/pull
```

Expected response: `{"clients":[...],"projects":[...],"entries":[...]}`
