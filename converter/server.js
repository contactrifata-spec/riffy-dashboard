// Link -> MP4/MP3 converter. Zero npm dependencies; shells out to yt-dlp + ffmpeg.
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { spawn } = require('child_process');

const PORT = process.env.PORT || 3000;
const YTDLP = process.env.YTDLP_PATH || 'yt-dlp';
const FFMPEG_DIR = process.env.FFMPEG_LOCATION || ''; // optional; default = on PATH
const ACCESS_CODE = process.env.ACCESS_CODE || '';     // set this when deployed publicly!
const COOKIES = process.env.COOKIES_FILE || '';        // optional Netscape cookies.txt
const MAX_CONCURRENT = 2;
const JOB_TTL_MS = 20 * 60 * 1000;
const WORK_DIR = path.join(os.tmpdir(), 'converter-jobs');
fs.mkdirSync(WORK_DIR, { recursive: true });

const ALLOWED_HOSTS = [
  'youtube.com', 'youtu.be', 'youtube-nocookie.com',
  'instagram.com', 'instagr.am',
  'tiktok.com',
];

const jobs = new Map(); // id -> {status, percent, file, name, error, dir, created}

function validateUrl(raw) {
  let u;
  try { u = new URL(String(raw).trim()); } catch { return null; }
  if (!['http:', 'https:'].includes(u.protocol)) return null;
  const h = u.hostname.toLowerCase();
  if (!ALLOWED_HOSTS.some(d => h === d || h.endsWith('.' + d))) return null;
  return u.toString();
}

function friendlyError(stderr) {
  const s = stderr || '';
  if (/Sign in to confirm|not a bot/i.test(s)) return 'YouTube blocked this server (bot check). Run the app from a home network or add cookies — see README.';
  if (/login required|rate-limit|Requested content is not available/i.test(s)) return 'Instagram needs a login for this post. Add cookies — see README.';
  if (/Private video|private/i.test(s)) return 'That video is private.';
  if (/Unsupported URL/i.test(s)) return 'That link type is not supported.';
  if (/Video unavailable|removed|not available/i.test(s)) return 'Video unavailable or removed.';
  const last = s.trim().split('\n').filter(Boolean).pop() || 'Download failed.';
  return last.replace(/^ERROR:\s*/, '').slice(0, 200);
}

function runJob(id, url, format) {
  const job = jobs.get(id);
  const dir = job.dir;
  const args = [
    '--no-playlist', '--newline', '--no-warnings', '--restrict-filenames',
    '--max-filesize', '1G',
    '-o', path.join(dir, '%(title).70B.%(ext)s'),
  ];
  if (FFMPEG_DIR) args.push('--ffmpeg-location', FFMPEG_DIR);
  if (COOKIES && fs.existsSync(COOKIES)) {
    // yt-dlp rewrites its cookie jar; secret-file mounts are read-only, so use a per-job copy.
    const jar = path.join(dir, '.cookies.txt');
    fs.copyFileSync(COOKIES, jar);
    args.push('--cookies', jar);
  }
  if (format === 'mp3') {
    args.push('-f', 'bestaudio/best', '-x', '--audio-format', 'mp3', '--audio-quality', '0', '--embed-metadata');
  } else {
    // Prefer H.264 + AAC so files play natively on iPhone / Photos.
    args.push('-f', 'bv*+ba/b', '-S', 'res:1080,vcodec:h264,acodec:m4a', '--merge-output-format', 'mp4');
  }
  args.push('--', url);

  job.status = 'running';
  const p = spawn(YTDLP, args, { stdio: ['ignore', 'pipe', 'pipe'] });
  let err = '';
  p.stdout.on('data', d => {
    for (const line of d.toString().split('\n')) {
      const m = line.match(/\[download\]\s+([\d.]+)%/);
      if (m) job.percent = Math.min(99, parseFloat(m[1]));
      if (/\[(Merger|ExtractAudio|VideoConvertor)\]/.test(line)) job.percent = 99;
    }
  });
  p.stderr.on('data', d => { err += d.toString(); });
  p.on('error', e => { job.status = 'error'; job.error = 'Server is missing yt-dlp (' + e.code + ').'; });
  p.on('close', code => {
    if (job.status === 'error') return;
    const wanted = format === 'mp3' ? '.mp3' : '.mp4';
    const f = fs.readdirSync(dir).find(n => n.toLowerCase().endsWith(wanted));
    if (code === 0 && f) {
      job.status = 'done'; job.percent = 100; job.file = path.join(dir, f); job.name = f;
    } else {
      job.status = 'error'; job.error = friendlyError(err);
      console.error('yt-dlp failed:', err.slice(-500));
    }
  });
}

function cleanup() {
  const now = Date.now();
  for (const [id, j] of jobs) {
    if (now - j.created > JOB_TTL_MS) {
      fs.rm(j.dir, { recursive: true, force: true }, () => {});
      jobs.delete(id);
    }
  }
}
setInterval(cleanup, 60 * 1000).unref();
// wipe leftovers from a previous run
for (const d of fs.readdirSync(WORK_DIR)) fs.rmSync(path.join(WORK_DIR, d), { recursive: true, force: true });

function json(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(obj));
}

function authed(req) {
  if (!ACCESS_CODE) return true;
  const got = String(req.headers['x-access-code'] || new URL(req.url, 'http://x').searchParams.get('code') || '');
  const a = Buffer.from(got), b = Buffer.from(ACCESS_CODE);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/json',
  '.webmanifest': 'application/manifest+json', '.png': 'image/png', '.svg': 'image/svg+xml' };

function serveStatic(req, res, pathname) {
  const rel = pathname === '/' ? '/index.html' : pathname;
  const file = path.join(__dirname, 'public', path.normalize(rel).replace(/^(\.\.[/\\])+/, ''));
  if (!file.startsWith(path.join(__dirname, 'public'))) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (e, data) => {
    if (e) { res.writeHead(404); return res.end('Not found'); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': path.extname(file) === '.html' || file.endsWith('sw.js') ? 'no-cache' : 'public, max-age=86400' });
    res.end(data);
  });
}

http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x');
  const p = u.pathname;

  if (p === '/api/config' && req.method === 'GET') return json(res, 200, { needsCode: !!ACCESS_CODE });

  if (p === '/api/convert' && req.method === 'POST') {
    if (!authed(req)) return json(res, 401, { error: 'Wrong access code.' });
    let body = '';
    req.on('data', d => { body += d; if (body.length > 10000) req.destroy(); });
    req.on('end', () => {
      let data; try { data = JSON.parse(body); } catch { return json(res, 400, { error: 'Bad request.' }); }
      const url = validateUrl(data.url);
      if (!url) return json(res, 400, { error: 'Paste a YouTube, Instagram, or TikTok link.' });
      const format = data.format === 'mp3' ? 'mp3' : 'mp4';
      const active = [...jobs.values()].filter(j => j.status === 'running' || j.status === 'queued').length;
      if (active >= MAX_CONCURRENT) return json(res, 429, { error: 'Busy — try again in a moment.' });
      const id = crypto.randomBytes(12).toString('hex');
      const dir = path.join(WORK_DIR, id);
      fs.mkdirSync(dir, { recursive: true });
      jobs.set(id, { status: 'queued', percent: 0, dir, created: Date.now() });
      runJob(id, url, format);
      json(res, 200, { id });
    });
    return;
  }

  let m;
  if ((m = p.match(/^\/api\/status\/([a-f0-9]{24})$/))) {
    if (!authed(req)) return json(res, 401, { error: 'Wrong access code.' });
    const j = jobs.get(m[1]);
    if (!j) return json(res, 404, { error: 'Expired. Convert again.' });
    return json(res, 200, { status: j.status, percent: j.percent, error: j.error, name: j.name });
  }

  if ((m = p.match(/^\/api\/file\/([a-f0-9]{24})$/))) {
    if (!authed(req)) { res.writeHead(401); return res.end('Wrong access code'); }
    const j = jobs.get(m[1]);
    if (!j || j.status !== 'done') { res.writeHead(404); return res.end('Not ready'); }
    const stat = fs.statSync(j.file);
    const mp3 = j.name.endsWith('.mp3');
    res.writeHead(200, {
      'Content-Type': mp3 ? 'audio/mpeg' : 'video/mp4',
      'Content-Length': stat.size,
      'Content-Disposition': `attachment; filename="${j.name.replace(/[^\w.\-]/g, '_')}"; filename*=UTF-8''${encodeURIComponent(j.name)}`,
    });
    return fs.createReadStream(j.file).pipe(res);
  }

  if (req.method === 'GET') return serveStatic(req, res, p);
  res.writeHead(405); res.end();
}).listen(PORT, () => console.log('Converter listening on :' + PORT + (ACCESS_CODE ? ' (access code on)' : ' (NO access code!)')));
