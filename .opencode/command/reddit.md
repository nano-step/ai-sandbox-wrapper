---
description: Draft a Reddit post optimized for a specific subreddit's rules, tone, and spam filters
---

Draft a Reddit post that follows a target subreddit's rules, matches community tone, and minimizes the risk of removal by mods or spam filters.

**Default language**: English (unless the user explicitly requests another language).

**Input**: The argument after `/reddit` is either:
- A filled input form (see template below)
- A free-form description of what the user wants to post and where

If the user provides free-form input, extract as much as possible and ask for missing required fields.

---

## Input Template

The user should provide these fields. Fields marked **(required)** must be collected before drafting.

### A. Target

| Field | Required | Description |
|-------|----------|-------------|
| Subreddit | **Yes** | e.g. `r/reactjs` |
| Rules/guidelines | **Yes** | Paste key rules, or say "use defaults" if a common sub |
| Flair options | **Yes** | Paste the available flair list from the post creation screen |
| Tag options | No | e.g. NSFW, Spoiler, Brand affiliate |

### B. Post Intent

| Field | Required | Description |
|-------|----------|-------------|
| Goal | **Yes** | `share` / `ask feedback` / `discussion` / `help` / `announcement` / `meta` / `job` |
| Post type | No | `text` (default) / `link` / `image` / `video` |
| Self-promo | **Yes** | `yes` / `no` |
| Commercial | No | `yes` / `no` (default: `no`) |
| AI-generated content | No | `unknown` / `allowed` / `disallowed` / `must disclose` |

### C. Content

| Field | Required | Description |
|-------|----------|-------------|
| One-liner | **Yes** | 1 factual sentence describing the project/topic |
| Problem/pain | **Yes** | 2-4 sentences: what pain point does this address? |
| Key points | **Yes** | 3-8 bullets: features, arguments, or insights |
| How it works / evidence | No | 2-5 bullets: technical details, benchmarks, limitations |
| Install/Try steps | No | Short (3-4 lines) or detailed (6-8 lines) |
| Links | No | demo, repo, docs, blog (max 4) |
| Feedback questions | Recommended | 2-4 specific questions for the community |
| Tone | No | `technical` (default) / `concise` / `story` |

---

## Steps

1. **Collect missing required fields**

   If any **(required)** field is missing, use the **AskUserQuestion tool** to ask for them.
   Ask all missing fields in ONE prompt (do not ask one at a time).

   **IMPORTANT**: Do NOT proceed to drafting without: Subreddit, Rules, Flair options, Goal, Self-promo flag, One-liner, Problem/pain, Key points.

2. **Parse rules and extract constraints**

   From the pasted rules/guidelines, extract:
   - **Hard constraints**: things that will get the post removed (banned content, required flair, link limits, promo policy, AI policy, specific post days like "Portfolio Sunday")
   - **Soft preferences**: community tone, encouraged behaviors, formatting expectations
   - **Spam signals**: account age requirements, self-promo ratio (e.g. 9:1 rule), link density limits

   Summarize constraints internally before drafting.

3. **Decide post strategy**

   Based on constraints + intent:
   - **Post format**: text post (default for self-promo; safer vs spam filters) or link post
   - **Link placement**: near the end (default) or inline (if sub expects it)
   - **Tone**: match community (technical subs -> technical; casual subs -> conversational)
   - **Structure**: Problem -> Solution -> Evidence -> Links -> Feedback questions

4. **Select flair + tags**

   From the user's flair/tag options:
   - Pick the **most appropriate flair** based on post intent and sub conventions
   - Recommend tags only if relevant (default: no tags)
   - **Never** select "Brand affiliate" unless user confirms it is commercial/brand content
   - Provide 1-line rationale for flair choice

5. **Draft the post**

   Generate:
   - **3-5 title options** (factual, no ALL CAPS, no opinion words like "best/ultimate", no vote-baiting)
   - **1 complete post body** (ready to copy-paste) following this structure:

   ```
   [Hook: 2-4 sentences describing the pain point]

   [What I built / What this is: 1-2 sentences]

   **[Section: key points as bullets]**

   **[Section: how it works / technical details]** (if provided)

   **[Section: how to try / install]** (if provided)

   **[Section: looking for feedback]**
   [2-4 specific questions]

   [Links: repo, demo, docs - placed at the end]
   ```

6. **Run compliance check**

   Verify the draft against ALL extracted constraints:
   - [ ] Title is factual, not editorialized
   - [ ] No vote-baiting language ("upvote", "show some love", "please star")
   - [ ] No ALL CAPS in title
   - [ ] Self-promo content has substance (not just links)
   - [ ] Link count is reasonable (2-4 max)
   - [ ] Flair is appropriate for content type
   - [ ] No "Brand affiliate" tag on non-commercial content
   - [ ] Feedback questions are specific (not generic "what do you think?")
   - [ ] Post matches community tone
   - [ ] No violations of sub-specific rules (AI policy, post day restrictions, etc.)

   If any check fails, fix the draft before presenting.

7. **Present the output**

   Deliver all sections clearly labeled (see Output below).

---

## Output

Always return these sections:

### 1. Titles (3-5 options)
```
1. [Title option 1]
2. [Title option 2]
3. [Title option 3]
```

### 2. Recommended Flair + Tags
```
Flair: [selected flair] - [1-line rationale]
Tags: [none / selected tags] - [rationale if any]
```

### 3. Post Body (ready to copy-paste)
```
[Complete post body]
```

### 4. Pre-post Checklist
```
Before posting, verify:
- [ ] Account has recent activity in this subreddit (not just self-promo)
- [ ] Flair is set to: [recommended flair]
- [ ] Post type is: [text/link]
- [ ] No rule violations detected
- [ ] [Any sub-specific check]
```

### 5. Risk Assessment
```
Spam risk: [Low / Medium / High]
Reason: [brief explanation]
Mitigation: [if medium/high, suggest actions like "comment helpfully in 2-3 threads first"]
```

---

## Guardrails

- **NEVER** include vote-baiting language in any form
- **NEVER** use ALL CAPS in titles
- **NEVER** select "Brand affiliate" without user confirmation
- **NEVER** skip the compliance check
- **NEVER** draft without collecting all required fields first
- **ALWAYS** default to text post for self-promo content (safer)
- **ALWAYS** place links near the end of the post body
- **ALWAYS** include specific feedback questions (not generic)
- **ALWAYS** write in English unless user explicitly requests another language
- If the user's content seems to violate sub rules, **warn them** and suggest adjustments rather than silently fixing
- If flair options don't have a good match, recommend the closest option and explain why
