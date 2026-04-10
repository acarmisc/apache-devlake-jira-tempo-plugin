# Apache DevLake Jira Tempo Plugin

Plugin DevLake per fare ingest dei worklog da Jira Tempo (Tempo Timesheets).

## Quick Start

```bash
cd ~/Projects/apache-devlake/backend
go build ./plugins/tempo/...
```

## Struttura

```
plugins/tempo/
├── impl/impl.go           # Plugin entrypoint
├── api/                 # REST endpoints
│   ├── connection.go    # Connection CRUD
│   ├── scope.go        # Team scopes
│   ├── scope_config.go  # Scope config
│   ├── remote.go       # Remote scopes
│   └── blueprint_v200.go
├── models/
│   ├── connection.go    # TempoConnection
│   ├── team.go        # TempoTeam
│   ├── worklog.go     # TempoWorklog
│   └── migrationscripts/
├── tasks/
│   ├── tasks.go       # SubTaskMetas
│   ├── api_client.go  # Tempo API client
│   ├── team_collector.go
│   ├── team_extractor.go
│   ├── worklog_collector.go
│   ├── worklog_extractor.go
│   └── worklog_convertor.go
└── e2e/
```

## Configurazione

| Campo | Descrizione |
|-------|-----------|
| name | "tempo" |
| connection | Bearer token (ApiKey) |
| scope | Tempo Team |

## Domain Mapping

| Tempo Field | DevLake Field |
|------------|--------------|
| tempoWorklogId | id = "tempo:TempoWorklog:{TempoWorklogId}" |
| IssueId | issue_id (resolve via jira:JiraIssues:{ConnectionId}:{IssueId}) |
| AuthorAccountId | author_id |
| TimeSpentSeconds/60 | time_spent_minutes |
| StartDate | started_date |

## API Endpoints

| Endpoint | Descrizione |
|----------|-------------|
| GET /worklogs | Worklogs in bulk (filter: project, issueId, from, to, updatedFrom) |
| GET /teams | Tempo teams |
| GET /work-attributes | Work attributes |

Base: `https://api.tempo.io/4`

Auth: Bearer token in header

## Sviluppo

### Test locale

```bash
# Start MySQL
docker run -d --name devlake-mysql -e MYSQL_ROOT_PASSWORD=root -p 3306:3306 mysql:8.0

# Build
cd backend && go build ./...

# Run
CONFIG=xxx lakexxx
```

### Riferimenti

- DevelopmentManual.md in backend/
- plugins/jira/ - pattern reference
- plugins/gitlab/ - pattern reference