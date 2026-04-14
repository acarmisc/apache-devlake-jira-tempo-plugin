# Changelog

## [unreleased] — 2025-04-14

### Added

- **CollectTeams**: implementato collector effettivo con paginazione server-side (`GET /4/teams?offset=&limit=`) e supporto incrementale `updatedFrom` (`tasks/team_collector.go`)
- **Filtro team nei worklog**: quando `TeamId != 0` il collector usa l'endpoint `GET /4/worklogs/team/{teamId}` con `from`/`to` obbligatori, fallback 90 giorni (`tasks/worklog_collector.go`)
- **FromDate/ToDate**: aggiunti a `TempoOptions` per specificare il range temporale nella collezione per team (`tasks/tasks.go`)
- **Route proxy**: registrata `connections/:connectionId/proxy/*path` → `api.Proxy` (`impl/impl.go`)
- **E2E TestTeamDataFlow**: test estrazione team da raw JSON (`e2e/worklog_test.go`)
- **E2E raw fixture**: `raw_tables/_raw_tempo_api_teams.csv` con dati raw per test estrazione
- **Grafana dashboard**: `grafana/dashboards/Tempo.json` — 3 pannelli (Ore per Team, Attività Giornaliera, Distribuzione per Autore) con variabili `$connection_id`, `$team`, `$author`
- **Deploy docs**: `docs/DEPLOY_AND_TEST.md` — guida italiana completa per build/deploy/verifica su K8s
- **Deploy script**: `scripts/deploy-test.sh` — automazione build+push+deploy+smoke test

### Fixed

- **TempoTeamResponse.Id**: tipo corretto da `string` a `int64` — l'API Tempo restituisce ID intero (`models/team.go`)
- **ConvertToToolLayer**: `TeamId` valorizzato con `r.Id` invece di `0` (`models/team.go`)
- **Remote scope pagination**: `listTempoRemoteTeams` usa `offset`/`limit` lato server, `searchTempoRemoteTeams` usa `name` query param (`api/remote.go`)
- **Remote scope connectionId**: `ConvertToToolLayer` riceve `connection.ID` invece di `0` (`api/remote.go`)
- **Custom string helpers**: sostituiti con `strings.Contains(strings.ToLower(...))` — rimosse `containsIgnoreCase`/`toLower`/`contains` (`api/remote.go`)
- **StartedDate/LoggedDate**: mappati rispettivamente da `StartDate+StartTime` e `CreatedAt` — non più `nil` (`tasks/worklog_convertor.go`)
- **IssueKey in extractor**: rimosso dalla `TempoWorklogResponse` — l'API non lo restituisce (`tasks/worklog_extractor.go`)
- **E2E double import**: rimosso doppio `ImportCsvIntoTabler` in `TestWorklogDataFlow`
- **E2E CSV fixtures**: `_tool_tempo_teams.csv` e `issue_worklogs.csv` allineati con i dati di input