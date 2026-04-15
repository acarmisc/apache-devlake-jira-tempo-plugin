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

## Releases

Pre-built artifacts are published as GitHub Releases on tag push (`v*`).

### Download

```bash
# Get the latest release
gh release download --repo <this-repo> --pattern "tempo-linux-amd64.so"
gh release download --repo <this-repo> --pattern "tempo-linux-arm64.so"
gh release download --repo <this-repo> --pattern "tempo-config-ui.zip"
gh release download --repo <this-repo> --pattern "Tempo.json"
```

Or download from the [Releases page](../../releases).

### Install

```bash
# 1. Copy the .so for your architecture to the DevLake plugin directory
mkdir -p <devlake>/bin/plugins/tempo/
cp tempo-linux-amd64.so <devlake>/bin/plugins/tempo/tempo.so

# 2. Extract config-ui files into the DevLake monorepo and rebuild the UI
unzip tempo-config-ui.zip -d <devlake>/

# 3. Import the Grafana dashboard
#    Grafana → Dashboards → Import → upload Tempo.json
```

### Build from source

Requires Go 1.20.5 (exact) and the DevLake monorepo:

```bash
# Checkout DevLake (use the same ref the release was built against)
git clone https://github.com/apache/incubator-devlake.git devlake
cd devlake/backend

# Overlay standalone plugin files
rsync -av --exclude='tempo.go' /path/to/this-repo/plugins/tempo/ ./plugins/tempo/

# Build (linux/amd64)
CGO_ENABLED=1 GOOS=linux GOARCH=amd64 CC=gcc \
  go build -buildmode=plugin -o tempo.so ./plugins/tempo/

# Build (linux/arm64)
CGO_ENABLED=1 GOOS=linux GOARCH=arm64 CC=aarch64-linux-gnu-gcc \
  go build -buildmode=plugin -o tempo.so ./plugins/tempo/
```

### Custom DevLake ref

The CI workflow builds against a specific DevLake commit. To build against a different ref, set the `DEVLAKE_REF` environment variable or edit the `DEFAULT_DEVLAKE_REF` in `.github/workflows/release.yml`.

## Building a Custom Docker Image

To create a Docker image that bundles DevLake with the Tempo plugin pre-installed, layer the `.so` file on top of an existing DevLake image.

### Multi-stage Dockerfile (recommended)

```dockerfile
# Stage 1: build the plugin .so from DevLake monorepo context
FROM --platform=linux/amd64 golang:1.20.5-bookworm AS builder

RUN apt-get update && apt-get install -y gcc

WORKDIR /app
# Copy the entire DevLake backend source (must include go.mod, core/, helpers/, etc.)
COPY devlake-backend/ .

# Overlay the standalone Tempo plugin (preserves tempo.go and other monorepo files)
COPY plugins/tempo/ ./plugins/tempo/

ENV CGO_ENABLED=1 GOARCH=amd64 GOOS=linux
RUN go build -buildmode=plugin -o /tempo.so ./plugins/tempo/

# Stage 2: layer tempo.so onto the DevLake base image
FROM your-devlake-base-image:tag

USER root
RUN mkdir -p /app/bin/plugins/tempo
COPY --from=builder /tempo.so /app/bin/plugins/tempo/tempo.so
RUN chown -R 1010:1010 /app/bin/plugins/tempo
USER 1010
```

### Quick build with Docker CLI

```bash
# 1. Build the plugin (requires DevLake monorepo + standalone plugin overlay)
#    See "Build from source" section above for rsync instructions.
CGO_ENABLED=1 go build -buildmode=plugin -o tempo.so ./plugins/tempo/

# 2. Build a custom image
docker build -t my-devlake:tempo-v0.1.0 -f - . <<EOF
FROM devlake/devlake:v1.0.0-beta9
USER root
RUN mkdir -p /app/bin/plugins/tempo
COPY tempo.so /app/bin/plugins/tempo/tempo.so
RUN chown -R 1010:1010 /app/bin/plugins/tempo
USER 1010
EOF
```

### Google Cloud Build example

```yaml
# cloudbuild.yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-f'
      - 'Dockerfile.cloudbuild'
      - '-t'
      - 'europe-west1-docker.pkg.dev/$PROJECT_ID/my-repo/devlake:${_IMAGE_TAG}'
      - '.'
    dir: 'backend'  # build context must be the DevLake backend directory
    waitFor: ['-']

images:
  - 'europe-west1-docker.pkg.dev/$PROJECT_ID/my-repo/devlake:${_IMAGE_TAG}'

substitutions:
  _IMAGE_TAG: 'tempo-latest'

options:
  logging: CLOUD_LOGGING_ONLY
  machineType: 'E2_HIGHCPU_8'
```

### Config-UI inclusion

To include the Tempo plugin in the DevLake config-UI, register it before building:

```bash
# In the DevLake monorepo's config-ui source
cd devlake/config-ui
unzip /path/to/tempo-config-ui.zip -d src/plugins/register/

# Add the import to src/plugins/register/index.ts
echo "import { TempoConfig } from './tempo';" >> src/plugins/register/index.ts
# Then add TempoConfig to the pluginConfigs array in the same file

# Build config-UI
yarn install && yarn build
```

### Helm deployment

Override the image reference in your Helm values to point to your custom image:

```yaml
lake:
  image:
    repository: europe-west1-docker.pkg.dev/my-project/my-repo/devlake
    tag: tempo-v0.1.0
    pullPolicy: Always
```

## References

- [Apache DevLake](https://github.com/apache/incubator-devlake)
- [Tempo API v4 Documentation](https://apidocs.tempo.io/)
- [DevLake Plugin Development](https://github.com/apache/incubator-devlake/blob/main/DevelopmentManual.md)
- [Jira Plugin Reference](https://github.com/apache/incubator-devlake/tree/main/backend/plugins/jira)
- [GitLab Plugin Reference](https://github.com/apache/incubator-devlake/tree/main/backend/plugins/gitlab)
