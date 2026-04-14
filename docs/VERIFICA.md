# Verifica del Lavoro Implementato

## 1. Compilazione (go vet nel monorepo)

```bash
cp -r plugins/tempo/ ~/Projects/apache-devlake/backend/plugins/tempo/
cd ~/Projects/apache-devlake/backend
go vet ./plugins/tempo/...
```

Verificato: passa senza errori.

## 2. E2E Tests (richiede MySQL)

```bash
docker run -d --name devlake-mysql -e MYSQL_ROOT_PASSWORD=root -p 3306:3306 mysql:8

cp -r plugins/tempo/ ~/Projects/apache-devlake/backend/plugins/tempo/
cd ~/Projects/apache-devlake/backend
E2E_DB_URL="root:root@tcp(localhost:3306)/lake" go test ./plugins/tempo/e2e/... -v
```

## 3. Build del .so

```bash
cd ~/Projects/apache-devlake/backend
PLUGIN_DIR=./bin/plugins go build -buildmode=plugin -o bin/plugins/tempo/tempo.so ./plugins/tempo/
```

## 4. Verifica API reale con il token

```bash
source .env

# Teams con paginazione server-side
curl -s -H "Authorization: Bearer $JIRA_TEMPO_API_KEY" \
  "https://api.tempo.io/4/teams?offset=0&limit=2" | python3 -m json.tool

# Worklogs per team 17 (endpoint team-filtered)
curl -s -H "Authorization: Bearer $JIRA_TEMPO_API_KEY" \
  "https://api.tempo.io/4/worklogs/team/17?from=2024-01-01&to=2025-04-14&offset=0&limit=2" | python3 -m json.tool
```

## 5. Deploy su K8s + smoke test

```bash
# Automatizzato
scripts/deploy-test.sh

# Oppure manuale: vedi docs/DEPLOY_AND_TEST.md
```

## 6. Dashboard Grafana

Dopo il deploy, verificare che Tempo.json sia caricato:
- Grafana → Dashboards → cerca "Tempo"
- Variabili: $connection_id, $team, $author
- Se non ci sono dati, triggerare prima una pipeline Tempo via Config-UI

## 7. Diff review rapido

```bash
git diff --stat
git diff plugins/tempo/
```

## Note LSP

Gli errori LSP nel plugin repo sono attesi: il plugin non ha un go.mod indipendente,
si compila nel contesto del monorepo DevLake. `go vet` nel monorepo passa pulito.