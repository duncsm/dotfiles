---
allowed-tools: mcp__plugin_slack_slack__slack_search_public_and_private, mcp__plugin_slack_slack__slack_read_thread, Bash(gws *), Bash(find *), Bash(stat *), Bash(wc *), Bash(head *), Bash(tail *), Bash(python3 *), Bash(mkdir *), Bash(gh *), Write, Agent
description: Generate a daily summary report of time spent across Slack, Calendar, Email, GitHub, and Claude Code sessions
---

# Daily Summary

Generates a comprehensive daily time-spent report by aggregating data from five sources: Slack messages, Google Calendar, Gmail, GitHub, and Claude Code sessions.

## Parameters

- **Date** (optional): Defaults to today. If the user specifies a date, use that instead. Format: YYYY-MM-DD.

## Execution Strategy: Parallel Subagents

**IMPORTANT:** Data collection MUST be parallelised using subagents. Launch **7 subagents simultaneously** using a single message with multiple Agent tool calls. Each subagent handles one data source independently. Once all subagents return, synthesise their results into the HTML report.

### Subagent dispatch (all launched in ONE message)

| # | Name | Description | Task |
|---|------|-------------|------|
| 1 | `slack-sent` | Slack messages sent | Collect all messages sent by user on date (section 1) |
| 2 | `slack-dms-received` | Slack DMs received | Collect all DMs/group DMs received (section 1b) |
| 3 | `slack-mentions` | Slack @mentions | Collect all @mentions of user (section 1c) |
| 4 | `calendar-events` | Calendar events | Fetch and parse calendar events (section 2) |
| 5 | `email-sent` | Gmail sent | Fetch and classify sent emails (section 3) |
| 6 | `github-activity` | GitHub activity | Fetch PRs, reviews, comments via gh CLI (section 5) |
| 7 | `claude-sessions` | Claude sessions | Find and extract session data (section 4) |

Each subagent prompt MUST include:
- The target date
- The user's Slack ID: `U028DPMV1TP`
- The user's GitHub handle: `duncsm`
- The exact tool calls and pagination instructions from the relevant section below
- Instruction to **return structured data** (not prose) — e.g. counts, lists, timestamps
- Instruction to **paginate through ALL results** before returning

Example dispatch (adapt date as needed):
```
Launch 7 Agent calls in a SINGLE message:

Agent(name="slack-sent", prompt="...section 1 instructions...return JSON-like structured summary...")
Agent(name="slack-dms-received", prompt="...section 1b instructions...")
Agent(name="slack-mentions", prompt="...section 1c instructions...")
Agent(name="calendar-events", prompt="...section 2 instructions...")
Agent(name="email-sent", prompt="...section 3 instructions...")
Agent(name="github-activity", prompt="...section 5 instructions...")
Agent(name="claude-sessions", prompt="...section 4 instructions...")
```

### After all subagents return

1. Parse each subagent's structured output
2. Cross-reference slack-sent and slack-dms-received to determine responded vs unresponded DMs
3. Cross-reference claude-sessions topics with github-activity to identify PRs "reviewed via Claude"
4. Compute time estimates using the Aggregation rules below
5. Generate the HTML report and write to ~/Documents/summaries/

## Data Collection

The user's Slack user_id is `U028DPMV1TP`.

### 1. Slack Messages Sent

Search for all messages the user sent on the target date. Paginate through ALL results.

```
Tool: mcp__plugin_slack_slack__slack_search_public_and_private
Query: from:<@U028DPMV1TP> on:{DATE}
Sort: timestamp (asc)
Limit: 20 per page
include_context: false
response_format: concise
```

Paginate using the cursor until all messages are collected. Record:
- Total message count
- Each unique channel/DM name
- Message content (for theme categorisation)

### 1b. Slack DMs Received (Requiring Response)

Search for DMs sent TO the user on the target date. Run a separate search:

```
Tool: mcp__plugin_slack_slack__slack_search_public_and_private
Query: to:<@U028DPMV1TP> on:{DATE}
Sort: timestamp (asc)
Limit: 20 per page
include_context: false
response_format: concise
channel_types: im,mpim
```

Paginate through ALL results. For each message, classify:
- **Channel type**: DM (`im`) or Group DM (`mpim`) vs public/private channel
- **Sender**: who sent it (extract from result)
- **Responded**: cross-reference with sent messages — if the user sent a message in the same DM/group DM on the same date, mark as responded

Build a DM inbox summary:
- Total DMs received (1:1 + group)
- Total unique senders
- DMs responded to vs not responded to
- Channel messages received (for comparison)

### 1c. Slack @mentions Received

Search for all messages where the user was explicitly tagged on the target date:

```
Tool: mcp__plugin_slack_slack__slack_search_public_and_private
Query: <@U028DPMV1TP> on:{DATE}
Sort: timestamp (asc)
Limit: 20 per page
include_context: false
response_format: concise
```

Paginate through ALL results. Exclude messages sent by the user themselves (those are self-mentions). For each mention, record:
- **Channel/DM name** and type (public channel, private channel, group DM, DM)
- **Sender** name
- **Message preview** (first ~100 chars)

Build a mentions summary:
- Total @mentions received (excluding self-mentions)
- Breakdown: mentions in channels vs mentions in DMs/group DMs
- Unique people who @mentioned you
- List of channels where you were mentioned

### 2. Google Calendar Events

```bash
gws calendar events list --params '{"calendarId": "primary", "timeMin": "{DATE}T00:00:00Z", "timeMax": "{DATE}T23:59:59Z", "singleEvents": true, "orderBy": "startTime"}'
```

Parse the JSON output. For each event extract:
- `start.dateTime` / `end.dateTime` (skip all-day events like working location)
- `summary` (meeting title)
- `attendees[].self.responseStatus` — only count events where user **accepted** or is the **organiser**
- Calculate duration in minutes

Skip events with `responseStatus: declined`.

### 3. Gmail Sent Messages

```bash
gws gmail users messages list --params '{"userId": "me", "q": "from:me after:{PREV_DATE} before:{NEXT_DATE}"}'
```

For each message ID returned, read with:
```bash
gws gmail +read --id "{MESSAGE_ID}"
```

Classify each email:
- **Calendar RSVP** (accepted/declined invitation) — count separately, not as composed email
- **Composed email** — count as actual sent email

Record: total composed emails, total RSVPs, recipients, subjects.

### 4. Claude Code Sessions

Find all session files modified on the target date:

```bash
find ~/.claude/projects -name "*.jsonl" -maxdepth 4
```

Filter to files with modification date matching the target date using `stat -f "%Sm" -t "%Y-%m-%d"`. Exclude subagent files (paths containing `/subagents/`).

For each matching session file, extract with python3:
- First and last timestamps containing the target date
- First human message (truncated to 120 chars) as the session topic
- Line count as a rough proxy for session size/complexity
- Project directory from the file path

### 5. GitHub Activity

The user's GitHub handle is `duncsm`. Use the `gh` CLI to collect all GitHub activity on the target date. The user does not do a lot of direct GitHub activity but does review PRs (sometimes via Claude Code).

#### 5a. PRs authored or updated

```bash
gh search prs --author=duncsm --updated="{DATE}..{DATE}" --json number,title,repository,state,url,createdAt,updatedAt --limit 50
```

#### 5b. PR reviews submitted

```bash
gh search prs --reviewed-by=duncsm --updated="{DATE}..{DATE}" --json number,title,repository,state,url,createdAt,updatedAt --limit 50
```

#### 5c. PR review comments

```bash
gh api "search/issues?q=commenter:duncsm+type:pr+updated:{DATE}..{DATE}&per_page=50" --jq '.items[] | {number: .number, title: .title, repo: .repository_url, url: .html_url}'
```

#### 5d. Cross-reference with Claude sessions

After the claude-sessions subagent returns, scan session topics for GitHub PR URLs (patterns like `github.com/.../pull/...` or mentions of "PR", "pull request", "review"). Note these as "Reviewed via Claude" in the GitHub section.

Return structured data:
1. PRS_AUTHORED: list with repo, PR number, title, state, URL
2. PRS_REVIEWED: list with repo, PR number, title, state, URL
3. PR_COMMENTS: list with repo, PR number, title, URL
4. TOTAL_PRS_TOUCHED: deduplicated count of unique PRs across all categories
5. REPOS_ACTIVE: list of unique repositories

## Aggregation & Time Estimation

### Meeting time
Sum durations of all accepted/organised timed calendar events. Report in hours and minutes.

### Slack time
Estimate active Slack time as: `message_count * 3 minutes` (accounts for reading context, typing, context-switching). Cap at a reasonable proportion of the day. Note this is an estimate.

### Claude Code time
For each session, calculate `last_timestamp - first_timestamp` for entries on the target date. Sum across all sessions. Note that long-running sessions may have idle gaps.

### Email time
Count composed emails (excluding RSVPs). Estimate ~5 minutes per composed email.

## Output Format

The report MUST be saved as an HTML file to `~/Documents/summaries/`.

### File naming

```
~/Documents/summaries/{REPORT_DATE}T{HH-MM-SS}-daily-summary.html
```

The date is the **report date** (the day being summarised). The time is the current generation time, so reruns don't overwrite. Ensure the directory exists (`mkdir -p ~/Documents/summaries`).

### HTML structure

Generate a self-contained HTML file with inline CSS. Use a clean, modern design with:
- Light background (#f8f9fa), white card sections with subtle shadows
- Colour-coded section headers (blue for meetings, purple for Slack, teal/cyan for GitHub, green for Claude, orange for email)
- Tables with alternating row colours and proper padding
- A sticky header bar with date and key stats
- Responsive layout that works on screen

After writing the file, output the file path as a clickable link: `[filename](file:///path/to/file)`

### Report sections (in order)

**1. Header bar** — Date, working location, status (e.g. Oncall), total tracked hours

**2. Day Summary** — Pie chart or bar of time breakdown (can be a simple CSS bar chart). Table of totals:

| Activity | Estimated Time |
|----------|---------------|
| Meetings | ... |
| Slack | ... |
| GitHub | ... |
| Claude Code | ... |
| Email | ... |
| **Total** | ... |

**Top themes today:** 2-3 sentence summary.

**3. Meetings ({total time})**

Table: Time, Duration, Meeting, Status. Declined meetings listed below in muted text.

**4. Slack ({message count} sent across ~{channel count} channels/DMs)**

**DM Inbox:**

| Metric | Count |
|--------|-------|
| DMs received (1:1) | ... |
| Group DMs received | ... |
| Total DMs needing response | ... |
| DMs responded to | ... |
| DMs not yet responded to | ... |
| Unique people who DM'd you | ... |

List any unresponded DMs with sender name and preview, highlighted in amber/yellow as action items.

**@Mentions:**

| Metric | Count |
|--------|-------|
| Total @mentions received | ... |
| In channels | ... |
| In DMs/group DMs | ... |
| Unique people who @mentioned you | ... |

Table of mentions: Sender, Channel, Preview. Group by channel.

**Activity themes:**

| Theme | Channels/DMs | Est. Messages |
|-------|-------------|---------------|
| ... grouped themes ... |

Estimated active Slack time: ~{estimate}

**5. GitHub ({total PRs touched} PRs across {repo count} repos)**

Use a teal/cyan colour for the section header (#0891b2).

Table: Repo, PR #, Title, Activity (authored / reviewed / commented), URL (clickable link).

If any Claude sessions referenced GitHub PRs, add a "Reviewed via Claude" subsection noting which PRs were opened in Claude sessions.

If there is no GitHub activity, show a brief "No direct GitHub activity on this date" message. Still check Claude sessions for PR references.

**6. Claude Code Sessions ({count} sessions, ~{total time} active)**

Table: Time, Duration, Topic

**7. Email**

Composed emails sent, calendar RSVPs. Table of sent emails with recipient and subject if any composed emails exist.

**8. Footer** — "Generated by Claude Code at {datetime}"

## Theme Categorisation

When grouping Slack messages into themes, look for:
- Incident channels (#im-*) — group as incident work
- Related DMs and channels about the same topic
- Management/people topics (1:1 follow-ups, team discussions)
- Project-specific channels
- Process/tooling discussions

Aim for 5-8 themes maximum. Each theme should have a short descriptive label.

## Notes

- All times are in the user's local timezone (UK/BST)
- Slack search may not capture messages in edit-only contexts (e.g. canvas edits)
- Claude session durations may overestimate if sessions were left idle
- The Slack time estimate is rough — it's hard to measure reading time
