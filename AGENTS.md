# Apache DevLake Jira Tempo Plugin

DevLake plugin for ingesting worklogs from Jira Tempo (Tempo Timesheets).

## Goal

Develop an Apache DevLake plugin to ingest worklogs from Jira Tempo (Tempo Timesheets). The plugin must:
1. Collect worklogs from Tempo API v4
2. Map data to DevLake domain layer `issue_worklogs`
3. Be configurable from DevLake UI

## Discoveries

**Tempo API v4 Worklog structure:**
```json
{
  "tempoWorklogId": 1696650,
  "issue": {"id": 291319},
  "timeSpentSeconds": 3600,
  "billableSeconds": 3600,
  "startDate": "2003-11-04",
  "startTime": "09:00:00",
  "description": "Working on issue",
  "author": {"accountId": "abc123"},
  "createdAt": "2024-12-01T10:24:17Z",
  "updatedAt": "2024-12-01T10:24:17Z"
}
```

**Domain Mapping (Tempo → DevLake):**
| Tempo Field | DevLake Field |
|------------|---------------|
| tempoWorklogId | id = "tempo:TempoWorklog:{tempoWorklogId}" |
| IssueId | issue_id (via jira:JiraIssues:{ConnectionId}:{IssueId}) |
| AuthorAccountId | author_id |
| TimeSpentSeconds/60 | time_spent_minutes |
| StartDate | started_date |

**Tempo API Endpoints:**
- `GET /4/worklogs` - paginated, filter by issueId, from, to, updatedFrom
- `GET /4/teams` - list teams
- Auth: Bearer token in header

**DevLake Plugin Loading:**
- Plugins compiled as `.so` in `PLUGIN_DIR` (default: `./plugins`)
- Loaded at runtime from `core/runner/loader.go`

## Accomplished

**COMPLETED:**
1. ✅ Cloned DevLake repo in `~/Projects/apache-devlake/`
2. ✅ Tested Tempo API with real credentials (`.env`)
3. ✅ Mapped Tempo data model → DevLake domain layer
4. ✅ Created base plugin scaffold
5. ✅ Created E2E test file with fixtures
6. ✅ Started MySQL Docker container (`devlake-mysql`)
7. ✅ Created `.env` config for DevLake backend
8. ✅ Fixed `TempoConnection` model with `helper.BaseConnection`
9. ✅ Fixed `TempoScopeConfig` with `ScopeConfigId()` and `ScopeConfigConnectionId()` methods
10. ✅ Fixed `TempoWorklog` with correct fields (tempoWorklogId, issueId, etc.)
11. ✅ Added `ConvertToToolLayer()` returning pointer `*TempoTeam`
12. ✅ Removed unused imports from various files
13. ✅ Fixed `testConnection` to use `*connection`
14. ✅ Build succeeds: `go build ./plugins/tempo/...`
15. ✅ Synced all missing files to personal repo
16. ✅ Committed plugin code to git
17. ✅ E2E tests pass
18. ✅ Config-UI integration (connection form works!)
19. ✅ Full README with database schema documentation

**IN PROGRESS:**
- Submit to upstream DevLake

**NOT STARTED:**
- Submit PR to Apache DevLake upstream

## Relevant Files / Directories

**Main repository (DevLake clone):**
- `/Users/andrea/Projects/apache-devlake/` (DevLake clone)
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/` (tempo plugin)
- `/Users/andrea/Projects/apache-devlake/backend/.env` (DevLake config)

**Personal repository:**
- `/Users/andrea/Projects/personal/apache-devlake-jira-tempo-plugin/` (plugin source)

**Plugin files:**
- `plugins/tempo/impl/impl.go` - Plugin entry point
- `plugins/tempo/models/connection.go` - TempoConnection, TempoScopeConfig
- `plugins/tempo/models/team.go` - TempoTeam
- `plugins/tempo/models/worklog.go` - TempoWorklog
- `plugins/tempo/tasks/tasks.go` - SubTaskMetas
- `plugins/tempo/tasks/api_client.go` - Tempo API client
- `plugins/tempo/tasks/worklog_collector.go` - CollectWorklogsMeta
- `plugins/tempo/tasks/worklog_extractor.go` - ExtractWorklogsMeta
- `plugins/tempo/tasks/worklog_convertor.go` - ConvertWorklogsMeta
- `plugins/tempo/api/connection.go` - Connection CRUD
- `plugins/tempo/api/remote.go` - Remote scopes
- `plugins/tempo/api/scope.go` - Scope operations
- `plugins/tempo/api/scope_config.go` - Scope config
- `plugins/tempo/api/blueprint_v200.go` - Pipeline plan

**Config-UI files:**
- `config-ui/src/plugins/register/tempo/config.tsx` - Plugin configuration
- `config-ui/src/plugins/register/tempo/index.ts` - Exports
- `config-ui/src/plugins/register/tempo/assets/icon.svg` - Icon

## Database Schema

### Tool Layer Tables

**`_tool_tempo_worklogs`**
| Column | Type | Description |
|--------|------|-------------|
| `id` | bigint | Primary key |
| `connection_id` | bigint | DevLake connection ID |
| `tempo_worklog_id` | bigint | Tempo worklog ID |
| `issue_id` | bigint | Jira issue ID |
| `time_spent_seconds` | int | Time spent in seconds |
| `billable_seconds` | int | Billable time |
| `start_date` | varchar | Work date |
| `start_time` | varchar | Start time |
| `description` | text | Description |
| `author_account_id` | varchar | Author account ID |
| `created_at` | datetime | Creation timestamp |
| `updated_at` | datetime | Update timestamp |

**`_tool_tempo_teams`**
| Column | Type | Description |
|--------|------|-------------|
| `id` | bigint | Primary key |
| `connection_id` | bigint | DevLake connection ID |
| `team_id` | varchar | Tempo team ID |
| `name` | varchar | Team name |
| `display_name` | varchar | Display name |

### Domain Layer

**`issue_worklogs`**
| Column | Type | Description |
|--------|------|-------------|
| `id` | varchar | `tempo:TempoWorklog:{TempoWorklogId}` |
| `author_id` | varchar | Author account ID |
| `time_spent_minutes` | int | Time spent in minutes |
| `logged_date` | date | Date work was logged |
| `started_date` | date | Work start date |
| `issue_id` | varchar | `jira:JiraIssues:{ConnectionId}:{IssueId}` |

## Next Steps

1. Submit PR to Apache DevLake upstream
2. Write more comprehensive E2E tests with real data
3. Add support for Tempo work attributes
4. Implement full scope selection UI with miller columns
