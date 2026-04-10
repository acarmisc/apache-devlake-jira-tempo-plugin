# Apache DevLake Jira Tempo Plugin

DevLake plugin for ingesting worklogs from Jira Tempo (Tempo Timesheets) API v4.

## Overview

This plugin collects worklog data from Jira Tempo and maps it to DevLake's domain layer (`issue_worklogs`), enabling time tracking analytics across your development workflow.

## Features

- **Worklog Collection**: Fetches worklogs from Tempo API v4 with pagination support
- **Team Management**: Collects Tempo teams for scope configuration
- **Domain Mapping**: Maps Tempo worklogs to DevLake's `issue_worklogs` domain
- **UI Integration**: Full configuration UI in DevLake's config-ui
- **Connection Management**: API key-based authentication with Tempo API

## Database Schema

### Tool Layer Tables (Plugin-specific)

**`_tool_tempo_worklogs`**
| Column | Type | Description |
|--------|------|-------------|
| `id` | bigint | Primary key (auto-increment) |
| `connection_id` | bigint | DevLake connection ID |
| `tempo_worklog_id` | bigint | Tempo worklog ID |
| `issue_id` | bigint | Jira issue ID |
| `time_spent_seconds` | int | Time spent in seconds |
| `billable_seconds` | int | Billable time in seconds |
| `start_date` | varchar | Work date (YYYY-MM-DD) |
| `start_time` | varchar | Start time (HH:MM:SS) |
| `description` | text | Worklog description |
| `author_account_id` | varchar | Tempo author account ID |
| `created_at` | datetime | Creation timestamp |
| `updated_at` | datetime | Last update timestamp |

**`_tool_tempo_teams`**
| Column | Type | Description |
|--------|------|-------------|
| `id` | bigint | Primary key (auto-increment) |
| `connection_id` | bigint | DevLake connection ID |
| `team_id` | varchar | Tempo team ID |
| `name` | varchar | Team name |
| `display_name` | varchar | Team display name |

**`_tool_tempo_connections`**
| Column | Type | Description |
|--------|------|-------------|
| `id` | bigint | Primary key |
| `name` | varchar | Connection name |
| `endpoint` | varchar | Tempo API endpoint |
| `token` | varchar | Encrypted API token |
| `proxy` | varchar | Proxy URL (optional) |
| `rate_limit_per_hour` | int | Rate limit |

### Domain Layer Tables

**`issue_worklogs`**
| Column | Type | Description |
|--------|------|-------------|
| `id` | varchar | Domain ID (format: `tempo:TempoWorklog:{TempoWorklogId}`) |
| `author_id` | varchar | Author account ID |
| `time_spent_minutes` | int | Time spent in minutes |
| `logged_date` | date | Date work was logged |
| `started_date` | date | Work start date |
| `issue_id` | varchar | Jira issue ID (format: `jira:JiraIssues:{ConnectionId}:{IssueId}`) |

### Entity Relationships

```
issue_worklogs (domain)
    └── issue_id → jira:JiraIssues:{ConnectionId}:{IssueId}
                     └── Requires Jira plugin data for mapping
```

**Note**: The Tempo plugin depends on the Jira plugin to provide the issue ID mapping. When configuring a Tempo connection, you should also have Jira connected to properly link worklogs to issues.

## Integration with Existing DevLake

### Option 1: Add to DevLake Core (Preferred for Upstream Contribution)

1. Copy plugin files to your DevLake clone:
```bash
# From this repository
cp -r plugins/tempo ~/Projects/apache-devlake/backend/plugins/
cp -r config-ui/src/plugins/register/tempo ~/Projects/apache-devlake/config-ui/src/plugins/register/
```

2. Update config-ui plugin registry:
```bash
# Add to config-ui/src/plugins/register/index.ts
import { TempoConfig } from './tempo';
// Add TempoConfig to the pluginConfigs array
```

3. Update DOC_URL (optional):
```bash
# Add TEMPO entry to config-ui/src/release/stable.ts
```

4. Build and run:
```bash
cd ~/Projects/apache-devlake/backend
PLUGIN_DIR=./bin/plugins go build -buildmode=plugin -o bin/plugins/tempo/tempo.so ./plugins/tempo/
DISABLED_REMOTE_PLUGINS=true go run server/main.go
```

### Option 2: Standalone Plugin Directory

For development/testing without modifying DevLake core:

```bash
cd ~/Projects/apache-devlake/backend

# Build plugin
mkdir -p bin/plugins/tempo
go build -buildmode=plugin -o bin/plugins/tempo/tempo.so ./plugins/tempo/

# Run with PLUGIN_DIR pointing to your plugin directory
PLUGIN_DIR=./bin/plugins DISABLED_REMOTE_PLUGINS=true go run server/main.go
```

### MySQL Setup

```bash
# Start MySQL container
docker run -d --name devlake-mysql \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=lake \
  -e MYSQL_USER=merico \
  -e MYSQL_PASSWORD=merico \
  -p 3306:3306 mysql:8.0

# Wait for initialization, then create user if needed
docker exec devlake-mysql mysql -u root -p -e \
  "CREATE USER IF NOT EXISTS 'merico'@'%' IDENTIFIED BY 'merico'; \
   GRANT ALL PRIVILEGES ON lake.* TO 'merico'@'%'; \
   FLUSH PRIVILEGES;"
```

## Development

### Prerequisites

- Go 1.21+
- Node.js 18+ (for config-ui)
- MySQL 8.0
- Docker (for local testing)

### Project Structure

```
apache-devlake-jira-tempo-plugin/
├── plugins/tempo/                    # Backend Go plugin
│   ├── impl/
│   │   └── impl.go                 # Plugin entry point (PluginMeta)
│   ├── api/
│   │   ├── connection.go           # Connection CRUD API
│   │   ├── scope.go                # Scope management
│   │   ├── scope_config.go         # Scope configuration
│   │   ├── remote.go               # Remote scope API
│   │   ├── init.go                 # Plugin initialization
│   │   └── blueprint_v200.go       # Blueprint v2.0.0 support
│   ├── models/
│   │   ├── connection.go           # TempoConnection, TempoScopeConfig
│   │   ├── team.go                 # TempoTeam model
│   │   ├── worklog.go              # TempoWorklog model
│   │   └── migrationscripts/        # Database migrations
│   ├── tasks/
│   │   ├── tasks.go                # SubTaskMetas definitions
│   │   ├── api_client.go           # Tempo API HTTP client
│   │   ├── team_collector.go        # Collect teams from Tempo
│   │   ├── team_extractor.go       # Extract teams to tool layer
│   │   ├── worklog_collector.go    # Collect worklogs from Tempo
│   │   ├── worklog_extractor.go    # Extract worklogs to tool layer
│   │   └── worklog_convertor.go    # Convert to domain layer
│   ├── e2e/
│   │   ├── worklog_test.go         # E2E test
│   │   └── snapshot_tables/         # Expected test data
│   └── tempo.go                    # Main entry point (for buildmode=plugin)
│
├── config-ui/src/plugins/register/tempo/  # Config-UI plugin
│   ├── config.tsx                  # Plugin configuration
│   ├── index.ts                   # Exports
│   └── assets/icon.svg             # Plugin icon
│
├── AGENTS.md                       # Development notes
└── README.md                       # This file
```

### Key Implementation Details

#### 1. Plugin Entry Point

```go
// impl/impl.go
type Tempo struct{}

func (p Tempo) Description() string {
    return "collect Jira Tempo worklogs"
}

func (p Tempo) SubTaskMetas() []plugin.SubTaskMeta {
    return []plugin.SubTaskMeta{
        tasks.CollectTeamsMeta,
        tasks.ExtractTeamsMeta,
        tasks.CollectWorklogsMeta,
        tasks.ExtractWorklogsMeta,
        tasks.ConvertWorklogsMeta,
    }
}
```

#### 2. API Client

The Tempo API client uses Bearer token authentication:

```go
// tasks/api_client.go
func NewTempoApiClient(connection *models.TempoConnection) (*apiclient.ApiClient, errors.Error) {
    apiClient, err := apiclient.NewApiClient(
        connection.Endpoint,
        nil,
        time.Minute,
        connection.Proxy,
        []string{"Authorization:Bearer " + connection.Token},
    )
    return apiClient, err
}
```

#### 3. Data Collection Flow

```
Tempo API v4
    │
    ▼
[Collector] → Raw Table (_raw_tempo_worklogs)
    │
    ▼
[Extractor] → Tool Table (_tool_tempo_worklogs)
    │
    ▼ (with Jira issue mapping)
[Convertor] → Domain Table (issue_worklogs)
```

#### 4. Domain ID Generation

Worklog IDs follow DevLake conventions:
```
id = "tempo:TempoWorklog:{TempoWorklogId}"
issue_id = "jira:JiraIssues:{ConnectionId}:{IssueId}"
```

### Building

```bash
# Build backend plugin
cd ~/Projects/apache-devlake/backend
go build -buildmode=plugin -o bin/plugins/tempo/tempo.so ./plugins/tempo/

# Run E2E tests
E2E_DB_URL='mysql://merico:merico@127.0.0.1:3306/lake?charset=utf8mb4&parseTime=True&loc=Local' \
  go test ./plugins/tempo/e2e/... -v
```

### Running

```bash
# Start DevLake backend
cd ~/Projects/apache-devlake/backend
export $(cat .env | xargs)  # DB_URL, PLUGIN_DIR, etc.
DISABLED_REMOTE_PLUGINS=true go run server/main.go

# Start Config-UI (separate terminal)
cd ~/Projects/apache-devlake/config-ui
npm start
```

Config-UI will be available at http://localhost:4000

### Tempo API Reference

Base URL: `https://api.tempo.io/4`

Authentication: Bearer token in `Authorization` header

Key Endpoints:
- `GET /worklogs` - List worklogs (supports `issueId`, `from`, `to`, `updatedFrom` filters)
- `GET /teams` - List Tempo teams
- `GET /work-attributes` - List work attributes

## Known Limitations

1. **Jira Dependency**: Worklog-to-issue mapping requires Jira plugin data. The Tempo plugin alone cannot create the full `issue_id` mapping without Jira data.

2. **No Tempo-specific UI for scope selection**: The plugin currently uses basic scope handling. For full team selection UI, additional miller-column implementation would be needed.

## References

- [Apache DevLake](https://github.com/apache/incubator-devlake)
- [Tempo API v4 Documentation](https://apidocs.tempo.io/)
- [DevLake Plugin Development](https://github.com/apache/incubator-devlake/blob/main/DevelopmentManual.md)
- [Jira Plugin Reference](https://github.com/apache/incubator-devlake/tree/main/backend/plugins/jira)
- [GitLab Plugin Reference](https://github.com/apache/incubator-devlake/tree/main/backend/plugins/gitlab)
