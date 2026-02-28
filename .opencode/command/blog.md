---
description: Draft SEO-optimized technology blog posts for multiple platforms based on the current project or latest changes
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

⚠️ **FIRST — check if `$ARGUMENTS` is exactly the word `help` (case-insensitive). If yes, jump directly to the [Help Output](#help-output) section below and STOP. Do NOT run any other phase.**

### Argument Parsing

Parse `$ARGUMENTS` to extract **platform selection**, **flags**, and **topic**.

**Syntax**: `/blog [platforms] [lang:vi|en] [file] [screenshot] [topic]`

All options are plain keywords — no dashes, no `--` prefix. This avoids conflict with the chat interface.

---

### Help Output

If `$ARGUMENTS` is `help` (case-insensitive, with or without extra whitespace), output the following help text **exactly** and then **STOP** — do not proceed to any other phase:

````
/blog — SEO-optimized blog post generator for multiple platforms

USAGE
  /blog [platforms] [options] [topic]

PLATFORMS (comma-separated, default: all)
  devto, dev.to        dev.to
  linkedin              LinkedIn (short post + long-form article)
  medium                Medium
  hashnode              Hashnode
  blog, hoainho         hoainho.info/blog (canonical source)
  thnk, thnkandgrow     thnkandgrow.com
  all                   All 6 platforms

OPTIONS (plain keywords, no dashes)
  lang:en               Write in English (default)
  lang:vi               Write in Vietnamese (tech terms stay in English)
  file                  Save output as .md files in ./blog-output/
  screenshot            Capture app screenshots via Playwright and embed in posts
  help                  Show this help message

EXAMPLES
  /blog help                                      Show this guide
  /blog                                           All platforms, English, auto-detect topic
  /blog devto,medium My new feature               dev.to + Medium only
  /blog lang:vi                                   All platforms, Vietnamese
  /blog linkedin lang:vi AI Sandbox tips           LinkedIn, Vietnamese
  /blog file hashnode Deep dive into auth          Hashnode, save to file
  /blog screenshot file blog,thnk Release v2      Personal blogs, screenshots, files
  /blog all lang:vi file screenshot               Full combo

OUTPUT (default: inline)
  Prints each platform version directly in chat, separated by ---

OUTPUT (file)
  ./blog-output/
  ├── index.md                      Summary with links to all versions
  ├── {slug}-devto.md               dev.to version with frontmatter
  ├── {slug}-linkedin-post.md       LinkedIn short post
  ├── {slug}-linkedin-article.md    LinkedIn long-form article
  ├── {slug}-medium.md              Medium version
  ├── {slug}-hashnode.md            Hashnode version
  ├── {slug}-hoainho.md             hoainho.info/blog version
  ├── {slug}-thnkandgrow.md         thnkandgrow.com version
  └── screenshots/                  (only with screenshot option)
      ├── hero.png                  Main app screenshot
      ├── feature-1.png             Key feature screenshots
      └── mobile.png                Mobile viewport

NOTES
  • Canonical URL is always hoainho.info/blog unless overridden
  • Posts include SEO keywords, meta descriptions, and platform-native formatting
  • Cross-platform publishing schedule included in output
  • Screenshots require a running dev server or build output
````

**Do NOT proceed with any other phase after printing help.**

---

#### Platform Identifiers

Case-insensitive, comma-separated, no spaces:

| Identifier | Platform |
|------------|----------|
| `devto` or `dev.to` | dev.to |
| `linkedin` | LinkedIn (both short post + long-form article) |
| `medium` | Medium |
| `hashnode` | Hashnode |
| `blog` or `hoainho` | hoainho.info/blog |
| `thnk` or `thnkandgrow` | thnkandgrow.com |
| `all` | All 6 platforms (default when no platform specified) |

#### Options

Plain keywords (no dashes) — can appear anywhere in `$ARGUMENTS`:

| Option | Default | Description |
|--------|---------|-------------|
| `lang:vi` | `en` | Generate all content in Vietnamese. Tech terms (React, Docker, API...) stay in English. |
| `lang:en` | `en` | Generate all content in English (default). |
| `file` | off | Save each platform version as a separate `.md` file in `./blog-output/` directory. File naming: `{slug}-{platform}.md` (e.g., `moodtrip-v2-devto.md`). Also creates an `index.md` with links to all versions. |
| `screenshot` | off | Include screenshots of the project. The agent will: (1) detect if the project has a running dev server or build output, (2) launch the app in a browser via Playwright, (3) capture key screens (homepage, main features, mobile view), (4) save screenshots to `./blog-output/screenshots/`, (5) embed image references in the blog content with descriptive alt text. If no UI is available (CLI tool, library), capture terminal output or architecture diagrams instead. |
| `help` | — | Display usage guide and exit. No content is generated. |

#### Parsing Rules

1. **Check `help` first** — if `$ARGUMENTS` is exactly `help` (case-insensitive), print help and stop immediately
2. Scan `$ARGUMENTS` for recognized platform identifiers (first comma-separated token)
3. Extract options (`lang:vi`, `lang:en`, `file`, `screenshot`) from anywhere in the arguments
4. Everything remaining after platforms and options is the **topic**
5. If no platform identifiers found → default to `all`
6. If no topic text → auto-detect topic from git activity
7. Options can appear in any order, before or after the topic

#### Examples

```
/blog help                                                     → show usage guide
/blog                                                          → all platforms, English, console output
/blog devto,medium Building a mood-based trip planner           → dev.to + Medium, English
/blog lang:vi                                                  → all platforms, Vietnamese, auto-detect topic
/blog linkedin lang:vi Chia sẻ hành trình xây dựng MoodTrip    → LinkedIn only, Vietnamese
/blog file devto,hashnode Introducing MoodTrip V2               → dev.to + Hashnode, save to files
/blog screenshot file blog,thnk MoodTrip V2 deep dive          → personal blogs, with screenshots, save to files
/blog all lang:vi file screenshot                              → everything: all platforms, Vietnamese, files, screenshots
```

**CRITICAL**: Only generate content for the selected platform(s). Skip all Phase 2 subsections for unselected platforms. Phase 3-5 output must also only reference selected platforms.

## Goal

Generate high-quality, SEO-optimized technology blog posts for **selected platforms** (default: all six — dev.to, LinkedIn, Medium, Hashnode, hoainho.info/blog, thnkandgrow.com). Only generate content for platforms specified in the argument parsing step. Each platform version must respect native formatting, optimal length, audience expectations, and discovery mechanics. Content is derived from the current project context and/or recent changes.

## Operating Constraints

- **Read-only analysis first**: Gather all project context before writing a single word.
- **Platform-native output**: Each platform version must be copy-paste ready with correct frontmatter/formatting.
- **Canonical source**: `hoainho.info/blog` is always the canonical URL unless user overrides.
- **Language**: Controlled by `--lang` flag. `--lang=en` (default) for English, `--lang=vi` for Vietnamese. When Vietnamese: use natural Vietnamese tech writing style, keep code/tech terms in English (React, Docker, API, etc.). If no `--lang` flag and user writes topic in Vietnamese, auto-set to `--lang=vi`.
- **No hallucinated features**: Only reference actual project capabilities confirmed by source code or docs.

## Execution Steps

### Phase 0: Context Gathering

1. **Read project metadata** — load in parallel:
   - `README.md` (project overview, features, value prop)
   - `AGENTS.md` (structure, conventions, tech stack)
   - `package.json` or equivalent manifest (dependencies, scripts, version)
   - Any `CHANGELOG.md` or `SESSION-SUMMARY.md` if present

2. **Analyze recent changes** (run from repo root):
   ```bash
   git log --oneline --no-decorate -20
   ```
   ```bash
   git diff HEAD~5..HEAD --stat
   ```
   ```bash
   git log --format="%s" -10
   ```

3. **Determine content source**:
   - If user provided a specific topic in `$ARGUMENTS` → use that as the primary angle
   - If `$ARGUMENTS` is empty → auto-detect the most interesting angle from recent git activity
   - If no recent activity → use the project overview as the angle

4. **Extract key facts** into an internal model (do not output this):
   - Project name and one-line description
   - Tech stack (languages, frameworks, tools)
   - Key features (top 3-5)
   - Recent changes (what changed, why it matters)
   - Unique differentiators (what makes this project special)
   - Target audience (who benefits from this project)

### Phase 1: Content Strategy

1. **Select blog post angle** — choose the most fitting type:
   | Type | When to use |
   |------|-------------|
   | Tutorial / How-to | New feature with clear usage steps |
   | Announcement | Major release, new tool, milestone |
   | Deep-dive | Complex architecture, design decisions |
   | Changelog / What's New | Multiple recent updates |
   | Case Study | Real-world usage, performance results |
   | Opinion / Lessons Learned | Insights from building the project |

2. **SEO keyword research** — generate:
   - **Primary keyword**: 2-4 word phrase (high search intent, moderate competition)
   - **Secondary keywords**: 3-5 related phrases
   - **Long-tail variants**: 2-3 question-based phrases (e.g., "how to sandbox AI agents")
   - **Semantic cluster**: 5-8 related terms to weave naturally into content

3. **Craft titles** — generate exactly 3 variants:
   - Variant A: Number/list format (e.g., "5 Reasons to Sandbox Your AI Coding Agent")
   - Variant B: How-to format (e.g., "How to Protect Your System from AI Coding Tools")
   - Variant C: Curiosity/bold claim (e.g., "Your AI Coding Agent Has Full Access to Your SSH Keys")
   - All titles must: contain the primary keyword (front-loaded), be under 60 characters, use power words

4. **Plan content structure** — outline with H2/H3 headings:
   - Hook → Problem → Solution → Implementation → Results → CTA
   - Every H2 section: 200-300 words max before next subheading
   - Include planned code block locations

### Phase 2: Write Platform-Specific Versions

Generate **separate, complete versions** for each platform below. Each version must be self-contained and copy-paste ready.

---

#### 2.1 — dev.to

**Format**: Markdown with Liquid tags

**Required frontmatter**:
```yaml
---
title: "[Your Title]"
published: false
tags: [tag1, tag2, tag3, tag4]  # max 4 tags
cover_image: ""  # suggest dimensions: 1000x420
canonical_url: "https://hoainho.info/blog/[slug]"
description: "[150-160 char meta description with primary keyword]"
series: ""  # optional, suggest if part of a series
---
```

**Writing rules**:
- Developer-friendly tone, practical and code-heavy
- 1500-3000 words optimal
- Use fenced code blocks with language identifiers (```bash, ```typescript, etc.)
- Emojis in H2 headings are acceptable and encouraged for scannability
- Include a `## TL;DR` section immediately after the intro
- End with `## What's Next?` and a clear CTA (star the repo, try the tool, comment)
- Tags are critical for discovery — choose tags with high follower counts on dev.to

---

#### 2.2 — LinkedIn

Generate **two versions**:

**Version A — Short Post** (1300-2000 characters):
```
[Hook line — must grab attention before "see more" fold]
[Second line — amplify the hook]

[3-5 bullet points or short paragraphs with key insights]

[Call-to-action: question to drive comments]

[3-5 hashtags, mix of broad (#AI, #DevTools) and niche (#AISandbox)]
```

**Writing rules for short post**:
- First 2 lines must compel the reader to click "see more"
- Use "I" statements and personal experience framing
- Unicode bold (𝗯𝗼𝗹𝗱) for emphasis where needed
- Line breaks between every 1-2 sentences (LinkedIn penalizes walls of text)
- End with a question to drive engagement
- Hashtags: 3-5, placed at the end

**Version B — Long-form Article** (1000-2000 words):
- Professional thought-leadership tone
- Frame technical content through business value lens
- Include a compelling subtitle
- Use bullet points and numbered lists generously
- Add a "Key Takeaways" section

---

#### 2.3 — Medium

**Format**: Rich Markdown

**Structure**:
- Kicker (short text above title, e.g., "Developer Tools")
- Title (compelling, keyword-rich)
- Subtitle (expands on title, adds context)
- Body: storytelling approach, narrative-driven
- 2000-4000 words (target 7-10 minute read)

**Writing rules**:
- Open with a story, analogy, or surprising statement
- Use pull quotes for key insights (> blockquote format)
- Code blocks with syntax highlighting
- Break into clear sections with descriptive H2 headings
- Include 1-2 images/diagrams suggestions with alt text
- End with a "Final Thoughts" section and CTA
- SEO focus: title, subtitle, first 150 characters are indexed
- Suggest 5 Medium tags (check relevance to Medium's tag ecosystem)

---

#### 2.4 — Hashnode

**Format**: Markdown with frontmatter

**Required frontmatter**:
```yaml
---
title: "[Your Title]"
slug: "[seo-optimized-slug-with-primary-keyword]"
cover: ""  # suggest dimensions: 1600x840
tags: [tag1, tag2, tag3, tag4, tag5]
canonical: "https://hoainho.info/blog/[slug]"
enableToc: true
---
```

**Writing rules**:
- Technical and educational tone, community-focused
- 1500-3000 words optimal
- Include auto-generated table of contents (TOC)
- Code snippets with clear explanations
- If part of a series, include series navigation links
- Hashnode SEO: slug is critical, meta description in first paragraph
- Include "Prerequisites" section if tutorial format
- End with "Resources" section with relevant links

---

#### 2.5 — hoainho.info/blog (Personal Blog — Canonical Source)

**Format**: Markdown or MDX (detect from project structure if possible, default to MDX)

**Frontmatter** (adapt to detected blog engine):
```yaml
---
title: "[Your Title]"
date: "[YYYY-MM-DD]"
description: "[150-160 char meta description]"
tags: [tag1, tag2, tag3]
author: "Hoai Nho"
slug: "[seo-optimized-slug]"
image: ""  # og:image recommendation
draft: true
---
```

**Writing rules**:
- Personal voice — this is the author's own blog
- Detailed technical deep-dives with personal insights and opinions
- Can be longer and more thorough than other platforms (no length cap)
- If Vietnamese content: use natural Vietnamese tech writing (not machine-translated), Vietnamese headings, but keep code/tech terms in English
- Include: author's perspective, lessons learned, behind-the-scenes decisions
- SEO: suggest schema markup (Article, TechArticle), og:title, og:description, og:image
- This is the **canonical URL** — all other platforms link back here

---

#### 2.6 — thnkandgrow.com

**Format**: Markdown/MDX

**Frontmatter**:
```yaml
---
title: "[Your Title — growth/learning angle]"
date: "[YYYY-MM-DD]"
description: "[meta description with growth/learning angle]"
tags: [tag1, tag2, tag3]
category: "Tech & Growth"
draft: true
---
```

**Writing rules**:
- Growth mindset framing — what did building this teach you?
- 1500-2500 words optimal
- Frame technical content through the lens of personal/professional growth
- **Required sections**:
  - "The Challenge" — what problem triggered this work
  - "The Journey" — what was learned along the way
  - "Key Takeaways" — 3-5 bullet points of actionable lessons
  - "Reflection Questions" — 2-3 questions for the reader to consider
- Tone: inspiring but grounded, not preachy
- Include: mindset shifts, failure moments, breakthrough insights
- CTA: encourage readers to share their own learning experiences

---

### Phase 3: SEO Optimization Pass

After drafting all versions, run this checklist on each:

| Check | Criteria |
|-------|----------|
| Title | Contains primary keyword in first 30 chars |
| Meta description | 150-160 chars, includes keyword, has CTA verb |
| H2 headings | At least 2 contain keyword variants |
| First paragraph | Contains primary keyword naturally |
| Image alt text | Descriptive, includes keyword where natural |
| Internal links | Suggest 1-2 links to related content |
| External links | Include 1-3 authoritative external references |
| Reading level | Grade 8-10 (use short sentences, common words) |
| Word count | Meets platform-specific optimal range |
| Code blocks | All have language identifiers for syntax highlighting |

### Phase 4: Cross-Platform Publishing Strategy

Output a publishing plan:

1. **Canonical URL**: `https://hoainho.info/blog/[slug]`

2. **Posting schedule** (stagger for maximum reach):
   | Day | Platform | Why this order |
   |-----|----------|----------------|
   | Day 1 | hoainho.info/blog | Canonical source, let Google index first |
   | Day 1 | thnkandgrow.com | Second owned property |
   | Day 2 | dev.to | Developer community, high engagement potential |
   | Day 2 | Hashnode | Technical community, SEO boost |
   | Day 3 | Medium | Broader audience, delayed for indexing |
   | Day 3-4 | LinkedIn (short post) | Professional network, drives traffic |
   | Day 5-7 | LinkedIn (article) | Long-form for sustained engagement |

3. **Cross-linking**: Each platform version links back to canonical. Mention other platforms where natural (e.g., "Read the full deep-dive on my blog").

4. **Repurposing ideas**:
   - LinkedIn short post → Twitter/X thread
   - Key code snippets → GitHub Gist → embed in posts
   - TL;DR → social media snippets
   - Key takeaways → carousel images for LinkedIn/Instagram

### Phase 5: Final Output

#### Mode A — Inline (default, no `--file` flag)

Present results directly in chat in this order:

1. **📋 Content Strategy Summary** — topic, angle, target audience (3-5 lines)
2. **🔑 SEO Analysis** — primary keyword, secondaries, title variants
3. **📝 Platform Versions** — each separated by `---` horizontal rules, only selected platforms:
   - dev.to version (complete with frontmatter)
   - LinkedIn short post
   - LinkedIn long-form article
   - Medium version (with kicker and subtitle)
   - Hashnode version (complete with frontmatter)
   - hoainho.info/blog version (complete with frontmatter)
   - thnkandgrow.com version (complete with frontmatter)
4. **✅ Publishing Checklist** (only selected platforms):
   ```
   [ ] Publish to hoainho.info/blog (canonical)
   [ ] Publish to thnkandgrow.com
   [ ] Submit to dev.to (set canonical_url)
   [ ] Submit to Hashnode (set canonical)
   [ ] Submit to Medium (import or paste, set canonical)
   [ ] Post LinkedIn short version
   [ ] Schedule LinkedIn long-form article
   [ ] Share on social media (Twitter/X, Reddit if relevant)
   [ ] Submit to relevant aggregators (Hacker News, Reddit communities)
   [ ] Monitor analytics after 24h and 7d
   ```
5. **📅 Posting Schedule** — the staggered timeline from Phase 4

#### Mode B — File Output (`--file` flag)

Create a `./blog-output/` directory in the project root and write files:

1. **Generate slug** from the title: lowercase, hyphens, no special chars (e.g., `introducing-moodtrip-v2`)

2. **Write platform files** — one per selected platform:
   | File | Content |
   |------|---------|
   | `{slug}-devto.md` | dev.to version with full frontmatter |
   | `{slug}-linkedin-post.md` | LinkedIn short post (plain text) |
   | `{slug}-linkedin-article.md` | LinkedIn long-form article |
   | `{slug}-medium.md` | Medium version with kicker/subtitle |
   | `{slug}-hashnode.md` | Hashnode version with full frontmatter |
   | `{slug}-hoainho.md` | hoainho.info/blog version |
   | `{slug}-thnkandgrow.md` | thnkandgrow.com version |

3. **Write `index.md`** — a summary file containing:
   - Content strategy summary
   - SEO analysis
   - Links to each platform file
   - Publishing checklist
   - Posting schedule

4. **Screenshots** (only if `--screenshot` flag):
   - Save to `./blog-output/screenshots/`
   - Files: `hero.png`, `feature-{n}.png`, `mobile.png`
   - Update image references in all platform files to use relative paths: `./screenshots/hero.png`

5. **Print summary** in chat:
   ```
   ✅ Blog output saved to ./blog-output/
   
   Files created:
     • blog-output/index.md
     • blog-output/{slug}-devto.md
     • blog-output/{slug}-linkedin-post.md
     • ...
   
   Next: review files, then follow the publishing checklist in index.md
   ```

## Writing Quality Standards

These standards apply to ALL platform versions:

- **Active voice** predominantly (passive only when emphasizing the object)
- **Hook first** — every version opens with a compelling hook (story, statistic, question, or bold claim)
- **Real code** — use actual code from the project, not pseudo-code or placeholders
- **Analogies** — explain at least one complex concept via analogy per post
- **Scannability** — subheadings every 200-300 words, bullet points for lists of 3+
- **TL;DR** — include a scannable summary section for developer-focused platforms
- **Clear CTA** — every version ends with an explicit call-to-action
- **No unexplained jargon** — define technical terms on first use or link to explanations
- **Transition phrases** — smooth flow between sections (avoid abrupt topic shifts)
- **Data when possible** — include performance numbers, statistics, or benchmarks where relevant
