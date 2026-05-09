# Build Your Personal Creator Dashboard
### A Claude Code Setup Guide

---

## What You're Building

A fully personal, single-file web dashboard that lives on Vercel and works on any device. It includes:

- **Daily schedule** — your actual blocks, color-coded by mode (script, film, edit, etc.)
- **Personal Branding pipeline** — track your content from idea → scripting → filming → editing → posted
- **UGC Client pipeline** — manage client deliverables separately
- **Habit tracker** — your own habits, checked off daily
- **Finance tracker** — linked to your own Google Sheet
- **Ideas board** — synced from your content spreadsheet
- **Content Research** — TikTok + Instagram analyzer for any creator
- **Social Media Analytics** — Claude AI tells you why your content works
- **iPhone widget** — live schedule on your home screen
- **Desktop + mobile notifications** — 5 min before each event

Everything is named after **you**, built around **your** schedule, and connected to **your** accounts.

---

## How to Use This File

**Paste the prompt below into Claude Code** (in your project folder). Claude will ask you questions first, then build everything. You don't need to know how to code.

---

## The Prompt — Paste This Into Claude Code

```
I want you to build me a fully personalized creator dashboard, similar to the one at https://github.com/contactrifata-spec/riffy-dashboard — but completely customized to me.

Before you write a single line of code, you need to interview me. Ask me every question below, one section at a time. Wait for my answers before moving to the next section. Once you have all my answers, build the full dashboard.

---

SECTION 1 — WHO YOU ARE

Ask me:
1. What's your name? (This will appear throughout the dashboard — "Good morning, [Name]")
2. What do you want to call yourself as a creator? (e.g. your handle, brand name, or just your first name)
3. What city/area are you based in? (Shows in the date bar)
4. What is your content niche or what kind of creator are you? (e.g. lifestyle, fitness, fashion, tech, finance, cooking — be specific)
5. What platforms do you post on? (TikTok, Instagram, YouTube, etc.)
6. What is your current goal as a creator? (e.g. hit 100K, land UGC clients, go full-time, build a brand)

---

SECTION 2 — YOUR DAILY SCHEDULE

Tell me: I need to build your exact daily schedule. I'll show you the current one as a template, but yours should reflect how you ACTUALLY want your day to look — not an ideal fantasy, your real working structure.

Ask me:
7. What time do you wake up?
8. Do you work out? If yes, what time and for how long?
9. Do you have a morning routine block? (journaling, coffee, getting ready) — what time and how long?
10. What time does your main creative work start?
11. Walk me through your creative blocks during the day:
    - Do you have separate blocks for scripting, filming, and editing?
    - What times are each of these? How long?
    - Do you work on UGC client content separately from your personal brand content? If yes, when?
12. Do you do admin/business work? (emails, pitches, invoicing) — what time and how long?
13. Do you take a lunch break? What time?
14. Any afternoon blocks? (second creative session, gym, errands, walks)
15. What time does your workday end?
16. Any evening routine? (free time, content review, journaling)
17. What time do you go to bed?
18. Which days do you work? (Mon-Fri? Mon-Sat? Do you take weekends off or work them?)
19. Do you want SCRIPT / FILM / EDIT mode buttons that color-code your creative blocks? (yes/no)

---

SECTION 3 — YOUR HABITS

Ask me:
20. What daily habits do you want to track? List all of them. Examples: gym, journaling, 8 glasses of water, no phone first hour, reading, meditation, posting content, etc.
21. For each habit — does it have a specific time or is it flexible?
22. Do you want a simple checkbox tracker or a streak counter?

---

SECTION 4 — YOUR CONTENT PIPELINE

Ask me:
23. Do you have a Google Sheet where you track your content ideas? If yes, what's the link? (This powers the Ideas sync)
24. What stages does your personal brand content go through? (Default: Idea → Scripting → Filming → Editing → Posted — do you want to change or add stages?)
25. Do you do UGC work for clients? If yes:
    a. What stages does your UGC workflow go through?
    b. Do you track client names, deadlines, or rates anywhere?
26. Do you have a content planning spreadsheet you want linked? (for the "Open Content Sheet" button)
27. Do you transcribe your videos? Do you have a preferred transcription tool?

---

SECTION 5 — YOUR FINANCES

Ask me:
28. Do you want a finance tracker in your dashboard? (yes/no)
29. If yes — do you have a Google Sheet for finances? What's the link?
30. What income categories do you want to track? (e.g. UGC, brand deals, affiliate, YouTube AdSense, other)
31. What expense categories? (e.g. equipment, software, props, food, travel)
32. Do you want to set a monthly income goal?
33. Do you want monthly or weekly financial summaries?

---

SECTION 6 — YOUR APIS AND TOOLS

Tell me: these are needed to power certain features. I'll walk you through getting each one — they're all free or cheap.

Ask me:
34. Do you have a Vercel account? (Free — needed to host the dashboard) — If not, I'll tell you how to set one up.
35. Do you have a GitHub account? (Free — needed to deploy) — If not, I'll tell you how.
36. Do you have an Apify account? (Free tier — needed for Instagram/TikTok analytics scraping)
    - If yes, paste your Apify API token.
37. Do you have an Anthropic/Claude API key? (Paid but cheap — needed for AI content analysis)
    - If yes, paste your Claude API key.
38. Do you have a RapidAPI account with tiktok-scraper7 subscribed? (Needed for TikTok single video analysis)
    - If yes, paste your RapidAPI key.
39. Do you want the iPhone widget feature? (Shows your schedule live on your home screen — requires a free Upstash Redis account and the Scriptable app on iPhone)
    - If yes, I'll walk you through getting your Upstash credentials.
40. Do you want desktop/mobile push notifications 5 minutes before each event?

---

SECTION 7 — LOOK AND FEEL

Ask me:
41. Do you prefer light mode, dark mode, or both with a toggle?
42. Do you want a minimal/clean look (lots of white space) or a more bold/graphic look?
43. Pick one: serif headers (classic, editorial) or sans-serif headers (clean, modern)?
44. Do you have a brand color? (hex code or just a color description — e.g. "dark green", "dusty rose", "electric blue")
45. Any other pages or features you want that aren't in the list above?

---

ONCE YOU HAVE ALL MY ANSWERS:

Build the full dashboard based on everything I told you. Here is the technical reference for how to build it:

TECH STACK:
- Single HTML file (index.html) deployed to Vercel via GitHub
- All state saved in localStorage
- Vercel serverless functions in /api/ folder for backend (Apify, Claude, Redis/widget sync)
- No frameworks, no npm, no build step — just vanilla HTML/CSS/JS

WHAT TO BUILD:
1. index.html — the main dashboard with:
   - Top bar with greeting (using my name), flip clock, date + city
   - Schedule section with my exact blocks, SCRIPT/FILM/EDIT mode buttons if requested, per-event timers, 🔔 notify button
   - Habit tracker with my habits
   - Tabs: Personal Branding pipeline | UGC Client pipeline | Ideas | Posting Calendar
   - Finance section with my categories and Google Sheet link
   - iPhone widget sync dot if requested

2. content-research.html — TikTok + Instagram analyzer with platform picker
   - TikTok: single video + profile scan (uses tiktok-scraper7 RapidAPI)
   - Instagram: single post + profile scan (uses Apify proxy)
   - Links to my transcription tool and content sheet

3. social-analytics.html — "What's actually working" page
   - Fetch my TikTok or Instagram posts via Apify
   - Claude AI gives deep profile-level insights + per-post "why it works" breakdown
   - Single video deep analysis section

4. /api/apify-start.js — starts Apify scraper run
5. /api/apify-status.js — polls Apify for results
6. /api/claude.js — proxies Claude API calls
7. /api/schedule.js — syncs schedule to Upstash Redis for iPhone widget (if requested)
8. /api/widget-script.js — serves Scriptable widget code (if requested)

PERSONALIZATION RULES:
- Replace "Riffy" with my name everywhere
- Replace "Brampton" with my city
- Use my schedule blocks exactly as I described
- Use my habit list
- Use my Google Sheet links
- Use my API keys
- Use my color if I gave one
- Write my mission statement in the dashboard using my stated goal
- Name the pipeline stages what I told you

After building, give me step-by-step instructions to deploy to Vercel and set up the iPhone widget if I requested it.
```

---

## What Happens After the Interview

Once you've answered all the questions, Claude Code will:

1. Build your full `index.html` dashboard
2. Build your `content-research.html` page
3. Build your `social-analytics.html` page
4. Set up all the `/api/` serverless functions
5. Give you deployment instructions for Vercel

**Total time:** About 20–30 minutes of building (plus your interview time).

---

## Quick Reference — What You'll Need

| Thing | Free? | Where to get it |
|---|---|---|
| GitHub account | Free | github.com |
| Vercel account | Free | vercel.com |
| Apify account | Free tier | apify.com |
| Claude API key | ~$5–20/mo usage | console.anthropic.com |
| RapidAPI (TikTok) | Free tier | rapidapi.com → search "tiktok-scraper7" |
| Upstash Redis | Free tier | upstash.com (only for iPhone widget) |
| Scriptable app | Free | App Store (only for iPhone widget) |

---

## Tips Before You Start

- **Be specific about your schedule.** Don't say "I work in the mornings." Say "I work from 10am to 1pm on scripting, then 2pm to 5pm on filming."
- **Your habits list should be real.** If you're not actually going to track it, don't add it.
- **The finance tracker is optional.** Skip it if you don't track money yet — you can always add it later.
- **You can always edit.** The dashboard is one HTML file. You can ask Claude Code to make any change at any time.
- **The name matters.** This dashboard will greet you by name every morning. Make it feel like yours.

---

*Built by Rifat · Template based on the Riffy Dashboard*
