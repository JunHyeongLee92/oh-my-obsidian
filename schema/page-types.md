---
type: schema
created: 2026-04-06
updated: 2026-04-20
---

# Page Types

Definitions of required and optional sections per wiki page type.

**Obsidian syntax**: For callouts, block references, highlights, and other recommended syntax per page type, see the "Recommended syntax per page type" table in `obsidian-syntax.md`.

## Project Page (`projects/{name}/index.md`)

Project entity page. Keep the current state always up to date.

### Required sections
- **Overview**: one-line description, goals, tech stack
- **Current state**: progress, open items, next steps
- **Architecture**: core structure summary (move detailed content into separate concept/guide pages)
- **Related links**: links to related entities, concepts, and decision pages

### Optional sections
- **Notes**: project-specific context and caveats

## Work Log Entry (`projects/{name}/worklog/YYYY-MM-DD.md`)

Daily record of work in detail.

### Required sections
- **Plan**: planned tasks for the day (checkboxes)
- **Done**: completed items (`[x]`)
- **Pending**: incomplete items (`[ ]`) with reason
- **Changed files**: table of file paths + description of the change

### Optional sections
- **Commits**: commit hash + message
- **Notes**: context, insights, references for the next session

## Decision Record (`projects/{name}/decisions/dec-NNN-*.md`)

Preserves the rationale behind a decision. ADR (Architecture Decision Record) format.

### Required sections
- **Context**: why this decision was needed
- **Decision**: the chosen direction
- **Alternatives considered**: comparison table (option / pros / cons)
- **Consequences**: what this decision affects

### Optional sections
- **Follow-ups**: concrete tasks triggered by the decision

## Jira Page (`projects/{name}/jira/piaxt-NNN.md`)

Per-ticket report content. Create only for projects that track Jira tickets.

### Required sections
- **Title**: the Jira ticket title
- **Work performed**: details of what was done
- **Outcome**: deliverables, changes

### Optional sections
- **Related worklog**: links to worklog dates tied to the ticket
- **Notes**: extra references

## Entity Page (`wiki/entities/*.md`)

People, organizations, tools, services, and the like.

### Required sections
- **Description**: what this entity is
- **Relations**: links to related entities, projects, and concepts

### Optional sections
- **Experience**: insights gained from using it
- **References**: links to official docs and related sources

## Concept Page (`wiki/concepts/*.md`)

Technical concepts, patterns, methodologies.

### Required sections
- **Definition**: what this concept is
- **Explanation**: details and how it works
- **Related concepts**: links to related concept pages

### Optional sections
- **Examples**: concrete code or cases
- **Sources**: links to source summary pages that cover this concept

## Guide Page (`wiki/guides/*.md`)

How-to guide. Practical procedure synthesized from sources.

### Required sections
- **Purpose**: the problem this guide solves
- **Procedure**: step-by-step instructions
- **Sources**: links to the source summaries that back the guide

### Optional sections
- **Prerequisites**: required environment and tools
- **Troubleshooting**: common issues and fixes

## Summary Page (`wiki/summaries/*.md`)

One summary per source. Output of the ingest action.

### Required sections
- **Source info**: title, author, URL, type, date
- **Key takeaways**: main-point summary
- **Extracted entities**: list of entities identified in this source + wiki links
- **Extracted concepts**: list of concepts identified in this source + wiki links

### Optional sections
- **Evaluation**: judgment about the source's reliability and usefulness
- **Quotes**: key sentences worth preserving from the original

## Digest Page (`wiki/digests/YYYY-WNN.md`)

Weekly re-synthesis. Generated automatically every Friday.

### Required sections
- **Weekly changes**: list + summary of added/changed wiki pages
- **Cross-domain analysis**: insights that connect materials from different domains
- **To watch next week**: topics that deserve follow-up investigation

### Optional sections
- **Stale-page reminders**: stale pages flagged by lint that are relevant to this week
