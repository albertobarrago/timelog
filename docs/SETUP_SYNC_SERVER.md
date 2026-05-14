# Setup Sync Server — note per nuovo Mac

## 1. File di configurazione locale

Crea il file `~/.config/timelog/sync.local` con questo contenuto:

```bash
mkdir -p ~/.config/timelog

cat > ~/.config/timelog/sync.local << 'EOF'
URL=https://timelog-server.vercel.app
API_KEY=LA_TUA_API_KEY
EOF

chmod 600 ~/.config/timelog/sync.local
```

> Sostituisci `LA_TUA_API_KEY` con la chiave che hai settato su Vercel.

L'app legge questo file al primo avvio e salva le credenziali in Keychain automaticamente.
Non serve inserire nulla nelle Settings.

## 2. Variabili d'ambiente Vercel (già settate, solo per riferimento)

Sul progetto `timelog-server` su Vercel sono configurate:
- `MONGODB_URI` — connection string MongoDB Atlas
- `API_KEY` — chiave segreta condivisa con l'app

Per recuperarle: `vercel env pull` dalla cartella `server/`.

## 3. Verifica rapida

```bash
curl -s -H "X-API-Key: LA_TUA_API_KEY" https://timelog-server.vercel.app/api/pull
```

Risposta attesa: `{"clients":[...],"projects":[...],"entries":[...]}`
