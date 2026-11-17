# Link Converter

Paste a YouTube / Instagram / TikTok link → download MP4 or MP3. Mobile-first PWA.

## Run locally (Mac)
    brew install yt-dlp ffmpeg
    ACCESS_CODE=yourpass node server.js     # http://localhost:3000

## Deploy (Render / Fly / Railway — anything that runs a Dockerfile)
Set env var `ACCESS_CODE` so strangers can't use your server. Then open the URL on your phone →
Share → **Add to Home Screen**.

## Why not Vercel?
Vercel functions have no ffmpeg/yt-dlp, a 10–60s time limit and ~4.5MB response cap. Use Vercel
only if you want a front-end there; the backend must run in a container.

## Env vars
- `ACCESS_CODE` – passcode required by the API (strongly recommended)
- `COOKIES_FILE` – path to Netscape cookies.txt (helps with Instagram / YouTube bot checks)
- `FFMPEG_LOCATION`, `YTDLP_PATH` – override binary locations

Note: YouTube often blocks datacenter IPs. Running at home (Mac + Tailscale/Cloudflare Tunnel) works best.

## Deploy on Render
1. Push this repo to GitHub.
2. Render dashboard → New → Blueprint → pick the repo/branch (it reads `render.yaml` at the repo root).
3. Enter `ACCESS_CODE` when prompted. Open the `.onrender.com` URL on your phone → Add to Home Screen.
