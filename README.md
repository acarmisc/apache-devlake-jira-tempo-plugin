# Apache DevLake Jira Tempo Plugin

DevLake plugin for ingesting worklogs from Jira Tempo (Tempo Timesheets).

## Structure

```
plugins/tempo/
├── impl/impl.go              # Plugin entrypoint
├── api/                      # REST endpoints
│   ├── connection.go          # Connection CRUD
│   ├── scope.go              # Team scopes
│   ├── scope_config.go       # Scope config
│   ├── remote.go             # Remote scopes
│   ├── init.go               # Helpers initialization
│   └── blueprint_v200.go     # Pipeline plan
├── models/
│   ├── connection.go         # TempoConnection, TempoScopeConfig
│   ├── team.go               # TempoTeam
│   ├── worklog.go            # TempoWorklog
│   └── migrationscripts/      # Database migrations
├── tasks/
│   ├── tasks.go              # SubTaskMetas
│   ├── api_client.go         # Tempo API client
│   ├── team_collector.go     # Team collector
│   ├── team_extractor.go    # Team extractor
│   ├── worklog_collector.go  # Worklog collector
│   ├── worklog_extractor.go  # Worklog extractor
│   └── worklog_convertor.go  # Worklog domain converter
└── e2e/
    └── worklog_test.go       # E2E tests
```

## Configuration

| Field | Description |
|-------|-------------|
| name | "tempo" |
| connection | Bearer token (ApiKey) |
| scope | Tempo Team |

## Domain Mapping

| Tempo Field | DevLake Field |
|-------------|---------------|
| tempoWorklogId | id = "tempo:TempoWorklog:{TempoWorklogId}" |
| IssueId | issue_id (via jira:JiraIssues:{ConnectionId}:{IssueId}) |
| AuthorAccountId | author_id |
| TimeSpentSeconds/60 | time_spent_minutes |
| StartDate | started_date |

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| GET /worklogs | Worklogs in bulk (filter: project, issueId, from, to, updatedFrom) |
| GET /teams | Tempo teams |
| GET /work-attributes | Work attributes |

Base: `https://api.tempo.io/4`

Auth: Bearer token in header

## Development

### Setup

```bash
# Clone DevLake
git clone https://github.com/apache/incubator-devlake.git ~/Projects/apache-devlake/

# Copy plugin to DevLake
cp -r plugins/tempo ~/Projects/apache-devlake/backend/plugins/

# Build
cd ~/Projects/apache-devlake/backend
go build ./plugins/tempo/...
```

### Local Testing

```bash
# Start MySQL
docker run -d --name devlake-mysql -e MYSQL_ROOT_PASSWORD=root -p 3306:3306 mysql:8.0

# Configure .env
cp .env.example .env

# Build and run DevLake
go build ./...
cd cmd && ./devlake
```

### References

- [DevelopmentManual.md](https://github.com/apache/incubator-devlake/blob/main/DevelopmentManual.md) in backend/
- `plugins/jira/` - pattern reference
- `plugins/gitlab/` - pattern reference
- [Tempo API v4 Docs](https://apidocs.tempo.io/)
