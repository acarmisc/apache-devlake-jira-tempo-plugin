# Apache DevLake Jira Tempo Plugin

DevLake plugin for ingesting worklogs from Jira Tempo (Tempo Timesheets).

## Goal

Develop an Apache DevLake plugin to ingest worklogs from Jira Tempo (Tempo Timesheets). The plugin must:
1. Collect worklogs from Tempo API v4
2. Map data to DevLake domain layer `issue_worklogs`
3. Be configurable from DevLake UI

## Instructions

- Use Tempo API v4 documentation (https://apidocs.tempo.io/) for endpoints and data model
- Follow DevLake Development Manual and existing plugin patterns (Jira, Gitlab)
- Align plugin code with DevLake conventions
- Clone DevLake in `~/Projects/apache-devlake/` for development
- Work in parallel with subagents using `cmux`
- Keep AGENTS.md updated

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
4. ✅ Created base plugin scaffold via subagent
5. ✅ Created E2E test file with fixtures
6. ✅ Started MySQL Docker container (`devlake-mysql`)
7. ✅ Created `.env` config for DevLake backend
8. ✅ Written AGENTS.md in personal repository
9. ✅ Fixed `TempoConnection` model with `helper.BaseConnection`
10. ✅ Fixed `TempoScopeConfig` with `ScopeConfigId()` and `ScopeConfigConnectionId()` methods
11. ✅ Fixed `TempoWorklog` with correct fields (tempoWorklogId, issueId, etc.)
12. ✅ Added `ConvertToToolLayer()` returning pointer `*TempoTeam`
13. ✅ Removed unused imports from various files
14. ✅ Fixed `testConnection` to use `*connection`
15. ✅ Build succeeds: `go build ./plugins/tempo/...`
16. ✅ Synced all missing files to personal repo
17. ✅ Committed plugin code to git

**IN PROGRESS:**
- Fix remaining build errors (if any)
- Test E2E with correct fixture format
- Local DevLake server testing
- UI integration

**NOT STARTED:**
- E2E test with correct CSV fixtures
- Local DevLake server testing
- UI integration

## Relevant Files / Directories

**Main repository (work):**
- `/Users/andrea/Projects/apache-devlake/` (DevLake clone)
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/` (tempo plugin)
- `/Users/andrea/Projects/apache-devlake/backend/.env` (DevLake config)

**Personal repository:**
- `/Users/andrea/Projects/personal/apache-devlake-jira-tempo-plugin/AGENTS.md`
- `/Users/andrea/Projects/personal/apache-devlake-jira-tempo-plugin/.env` (with `JIRA_TEMPO_API_KEY`)

**Plugin files (in progress):**
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/impl/impl.go` - Entry point
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/models/connection.go` - TempoConnection, TempoConn, TempoScopeConfig
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/models/team.go` - TempoTeam, TempoTeamResponse
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/models/worklog.go` - TempoWorklog
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/tasks/tasks.go` - SubTaskMetas, constants
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/tasks/api_client.go` - NewTempoApiClient
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/tasks/worklog_collector.go` - CollectWorklogsMeta
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/tasks/worklog_extractor.go` - ExtractWorklogsMeta
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/tasks/worklog_convertor.go` - ConvertWorklogsMeta
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/tasks/team_collector.go` - CollectTeamsMeta
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/api/init.go` - Helpers initialization
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/api/connection.go` - Connection CRUD
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/api/remote.go` - Remote scopes
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/api/scope.go` - Scope operations
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/api/scope_config.go` - Scope config
- `/Users/andrea/Projects/apache-devlake/backend/plugins/tempo/api/blueprint_v200.go` - Pipeline plan

**Next steps:**
1. Fix any remaining build errors
2. Verify `go build ./plugins/tempo/...` compiles without errors
3. Create E2E test fixtures in correct CSV format
4. Test plugin with local DevLake server
