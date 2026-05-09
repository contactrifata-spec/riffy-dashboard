// api/widget-script.js — serves the Scriptable widget code as plain text
// Scriptable on iPhone can load scripts directly from a URL
export default function handler(req, res) {
  const host = req.headers.host || 'your-vercel-url.vercel.app';
  const baseUrl = `https://${host}`;

  const script = `
// ─────────────────────────────────────────
// Riffy Dashboard — Schedule Widget
// Auto-synced from your dashboard
// ─────────────────────────────────────────

const SCHEDULE_URL = "${baseUrl}/api/schedule";
const DASHBOARD_URL = "${baseUrl}";

// ── Fetch schedule ──────────────────────
let schedule = [];
try {
  const req = new Request(SCHEDULE_URL);
  req.timeoutInterval = 8;
  const data = await req.loadJSON();
  schedule = (data.schedule || []).filter(s => s && s.time && s.label);
} catch (e) {
  schedule = [{ time: "–:––", label: "Tap to open dashboard", type: "flex" }];
}

// ── Time helpers ────────────────────────
function parseMins(t) {
  if (!t) return 0;
  const m = t.match(/(\\d+):(\\d+)\\s*(AM|PM)/i);
  if (!m) return 0;
  let h = +m[1], mn = +m[2], ap = m[3].toUpperCase();
  if (ap === "PM" && h !== 12) h += 12;
  if (ap === "AM" && h === 12) h = 0;
  return h * 60 + mn;
}

function stripEmoji(s) {
  return s.replace(/[\\u{1F000}-\\u{1FFFF}]|[\\u{2600}-\\u{26FF}]|[\\u{2700}-\\u{27BF}]/gu, "").trim();
}

const now = new Date();
const nowMins = now.getHours() * 60 + now.getMinutes();
const withMins = schedule.map(s => ({ ...s, mins: parseMins(s.time) }));

// Find current event (last one whose time has passed)
let curIdx = withMins.reduce((best, s, i) => s.mins <= nowMins ? i : best, 0);

// ── Colors ──────────────────────────────
const BG       = new Color("#ffffff");
const BG_DARK  = new Color("#1c1c1e");
const RED      = new Color("#ef4444");
const YELLOW   = new Color("#ca8a04");
const ORANGE   = new Color("#ea580c");
const GRAY     = new Color("#9a9a9a");
const DIM      = new Color("#c8c8c8");
const TEXT     = Device.isUsingDarkAppearance() ? new Color("#f2f2f0") : new Color("#1a1a1a");
const SUBTEXT  = Device.isUsingDarkAppearance() ? new Color("#9a9a9a") : new Color("#555555");
const PAST     = Device.isUsingDarkAppearance() ? new Color("#444444") : new Color("#cccccc");
const SURFACE  = Device.isUsingDarkAppearance() ? BG_DARK : BG;

function typeColor(type) {
  if (type === "prayer")       return new Color("#16a34a");
  if (type === "gym")          return new Color("#a855f7");
  if (type === "locked")       return new Color("#64748b");
  if (type === "script-block") return YELLOW;
  if (type === "film-block")   return RED;
  if (type === "edit-block")   return ORANGE;
  if (type === "meeting")      return new Color("#3b82f6");
  return GRAY;
}

// ── Build widget ────────────────────────
const w = new ListWidget();
w.backgroundColor = SURFACE;
w.setPadding(14, 16, 14, 16);
w.url = DASHBOARD_URL;
w.refreshAfterDate = new Date(Date.now() + 5 * 60 * 1000); // refresh every 5 min

// Header row
const hdr = w.addStack();
hdr.layoutHorizontally();
hdr.centerAlignContent();

const title = hdr.addText("🗓 Today's Schedule");
title.font = Font.boldSystemFont(13);
title.textColor = TEXT;
hdr.addSpacer();

const clockTxt = hdr.addText(
  now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
);
clockTxt.font = Font.systemFont(11);
clockTxt.textColor = SUBTEXT;

w.addSpacer(10);

// Event rows — show 1 before current + next 5
const startIdx = Math.max(0, curIdx - 1);
const endIdx   = Math.min(withMins.length, startIdx + 7);

for (let i = startIdx; i < endIdx; i++) {
  const item      = withMins[i];
  const isCurrent = i === curIdx;
  const isPast    = i < curIdx;
  const accent    = typeColor(item.type);

  const row = w.addStack();
  row.layoutHorizontally();
  row.centerAlignContent();
  row.spacing = 6;

  // Active indicator bar
  const bar = row.addStack();
  bar.layoutVertically();
  bar.size = new Size(3, 18);
  bar.backgroundColor = isCurrent ? accent : new Color("#00000000");
  bar.cornerRadius = 2;

  row.addSpacer(4);

  // Time
  const timeTxt = row.addText(item.time);
  timeTxt.font = Font.boldMonospacedSystemFont(10);
  timeTxt.textColor = isCurrent ? accent : isPast ? PAST : SUBTEXT;
  timeTxt.minimumScaleFactor = 0.7;

  row.addSpacer(4);

  // Label
  const label = stripEmoji(item.label);
  const labelTxt = row.addText(label);
  labelTxt.font = isCurrent ? Font.boldSystemFont(12) : Font.systemFont(11);
  labelTxt.textColor = isCurrent ? TEXT : isPast ? PAST : SUBTEXT;
  labelTxt.lineLimit = 1;
  labelTxt.minimumScaleFactor = 0.8;

  w.addSpacer(5);
}

// Footer
w.addSpacer();
const footer = w.addText("Tap to open dashboard");
footer.font = Font.systemFont(9);
footer.textColor = PAST;
footer.centerAlignText();

Script.setWidget(w);
if (config.runsInApp) await w.presentMedium();
Script.complete();
`.trim();

  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.status(200).send(script);
}
