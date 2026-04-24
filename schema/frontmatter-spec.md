---
type: schema
created: 2026-04-06
updated: 2026-04-20
---

# Frontmatter Spec

YAML frontmatter schema for every wiki page.

## Common fields (every page)

```yaml
---
type: project | entity | concept | decision | guide | summary | worklog | digest | jira
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: []
aliases: []
status: active | stale | archived
---
```

| Field     | Required | Description                                                             |
|-----------|----------|-------------------------------------------------------------------------|
| `type`    | Yes      | Page type (see `page-types.md`)                                         |
| `created` | Yes      | Creation date                                                           |
| `updated` | Yes      | Last modification date                                                  |
| `tags`    | No       | Free-form tags                                                          |
| `aliases` | No       | Alternative names for this page                                         |
| `status`  | Yes      | Page status. Lint uses it to decide whether the page is stale           |

## Per-type additional fields

### Project (`type: project`)

```yaml
project-status: planning | active | paused | completed
repo-url: ""
tech-stack: []
```

| Field             | Required | Description                 |
|-------------------|----------|-----------------------------|
| `project-status`  | Yes      | Project progress state      |
| `repo-url`        | No       | Code repository URL         |
| `tech-stack`      | No       | List of technologies used   |

### Decision (`type: decision`)

```yaml
decision-status: proposed | accepted | deprecated | superseded
superseded-by: ""
project: ""
```

| Field             | Required | Description                                          |
|-------------------|----------|------------------------------------------------------|
| `decision-status` | Yes      | Decision state                                       |
| `superseded-by`   | No       | Link to a new decision page that replaces this one   |
| `project`         | Yes      | Name of the related project                          |

### Summary (`type: summary`)

```yaml
source-path: ""
source-type: paper | article | conversation | project-artifact | misc
source-url: ""
ingested-date: YYYY-MM-DD
```

| Field           | Required | Description                                                 |
|-----------------|----------|-------------------------------------------------------------|
| `source-path`   | Yes      | Path of the original file under `_sources/`                 |
| `source-type`   | Yes      | Source type                                                 |
| `source-url`    | No       | Original URL (for web sources)                              |
| `ingested-date` | Yes      | Date the ingest action was performed                        |

### Work Log (`type: worklog`)

```yaml
project: ""
date: YYYY-MM-DD
```

| Field    | Required | Description                  |
|----------|----------|------------------------------|
| `project`| Yes      | Name of the related project  |
| `date`   | Yes      | Date of the work             |

### Entity (`type: entity`)

```yaml
entity-type: person | organization | tool | service | library | framework
```

| Field          | Required | Description           |
|----------------|----------|-----------------------|
| `entity-type`  | Yes      | Entity classification |

### Concept (`type: concept`)

Beyond the common fields, optionally:

```yaml
source-type: learning-session
```

| Field         | Required | Description                                                                                                                                                        |
|---------------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `source-type` | No       | Provenance of this concept. `learning-session` = promoted from an `/omo-study` session. Concepts extracted from external sources usually omit this field and instead link back via `[[summary-link]]`. |

### Guide (`type: guide`)

No extra fields. Uses only the common fields.

### Digest (`type: digest`)

```yaml
week: YYYY-WNN
```

| Field   | Required | Description                        |
|---------|----------|------------------------------------|
| `week`  | Yes      | ISO week, e.g. `2026-W14`          |

### Jira (`type: jira`)

```yaml
ticket-id: PIAXT-NNN
ticket-status: todo | in-progress | done
project: ""
```

| Field            | Required | Description                            |
|------------------|----------|----------------------------------------|
| `ticket-id`      | Yes      | Jira ticket ID (e.g. `PIAXT-271`)      |
| `ticket-status`  | Yes      | Ticket state                           |
| `project`        | Yes      | Name of the related project            |

## System pages

`wiki/index.md` and `wiki/log.md` are wiki-infrastructure pages; they use dedicated types distinct from regular pages.

- `type: index` — full wiki index. Excluded from lint validation.
- `type: log` — wiki change history. Excluded from lint validation.
