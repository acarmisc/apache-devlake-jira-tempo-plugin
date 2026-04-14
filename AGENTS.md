# Apache DevLake Jira Tempo Plugin

DevLake plugin for ingesting worklogs from Jira Tempo (Tempo Timesheets).

## Quick Commands

```bash
# Build plugin (.so must go in ./bin/plugins/tempo/)
PLUGIN_DIR=./bin/plugins go build -buildmode=plugin -o bin/plugins/tempo/tempo.so ./plugins/tempo/

# Run E2E tests (requires MySQL container: docker run -d --name devlake-mysql -e MYSQL_ROOT_PASSWORD=root -p 3306:3306 mysql:8)
go test ./plugins/tempo/e2e/... -v
```

## Architecture

- **Not a standalone project** - plugin lives in Apache DevLake repo at `~/Projects/apache-devlake/backend/plugins/tempo/`
- **Plugin loading** - compiled as `.so` in `PLUGIN_DIR` (default `./bin/plugins`), loaded at runtime by `core/runner/loader.go`
- **Entry point** - `plugins/tempo/impl/impl.go` implements `plugin.Plugin` interface

## Key Files

| File | Purpose |
|------|---------|
| `impl/impl.go` | Plugin entry point, registers subtasks |
| `models/connection.go` | TempoConnection, TempoScopeConfig |
| `models/worklog.go` | TempoWorklog tool layer model |
| `tasks/api_client.go` | Tempo API v4 client (Bearer token auth) |
| `tasks/worklog_collector.go` | CollectWorklogsMeta |
| `tasks/worklog_convertor.go` | ConvertWorklogsMeta → domain layer |
| `api/connection.go` | Connection CRUD endpoints |

## Tempo API

- Base: `GET /4/worklogs` - paginated, filters: issueId, from, to, updatedFrom
- Auth: Bearer token in header
- Response: `{ tempoWorklogId, issue: {id}, timeSpentSeconds, startDate, startTime, author: {accountId}, ... }`

## Domain Mapping

| Tempo Field | DevLake Field |
|------------|---------------|
| tempoWorklogId | id = `tempo:TempoWorklog:{tempoWorklogId}` |
| issue.id | issue_id = `jira:JiraIssues:{ConnectionId}:{IssueId}` |
| author.accountId | author_id |
| timeSpentSeconds/60 | time_spent_minutes |
| startDate | started_date |

## Database Tables

**Tool layer:** `_tool_tempo_worklogs`, `_tool_tempo_teams`  
**Domain layer:** `issue_worklogs` (mapped from Tempo worklogs)

## Testing

- E2E tests in `plugins/tempo/e2e/` require running DevLake backend with MySQL
- Set `MYSQL_ROOT_PASSWORD=root` on MySQL container
- Config-UI integration in `config-ui/src/plugins/register/tempo/`