# Deploy e Test del Plugin Tempo per Apache DevLake

Guida completa per il build, deploy e verifica del plugin Tempo (worklogs Jira) su un cluster Kubernetes.

---

## 1. Prerequisiti

- **Repository clonati:**
  - `apache-devlake-jira-tempo-plugin` — questo repo (codice del plugin)
  - `apache-devlake` — monorepo upstream di DevLake (contiene `backend/`)
- **Docker** con buildx per build multi-platform (linux/amd64)
- **Accesso a GCP Artifact Registry** (`europe-west1-docker.pkg.dev/abs-digital-playground/apache-devlake`)
- **kubectl** configurato per il cluster target (namespace `devlake`)
- **Helm 3** installato
- **Go 1.20+** (per build locale opzionale)
- **mysql** client (per query di verifica)

### Variabili d'ambiente

```bash
export DEVLAKE_MONOREPO="$HOME/Projects/apache-devlake/backend"
export PLUGIN_REPO="$HOME/Projects/personal/apache-devlake-jira-tempo-plugin"
export IMAGE_REPO="europe-west1-docker.pkg.dev/abs-digital-playground/apache-devlake/devlake"
export NAMESPACE="devlake"
```

---

## 2. Build dell'immagine Docker

Il Dockerfile usa un build multi-stage:

1. **Stage 1** — compila `tempo.so` dal contesto del monorepo DevLake
2. **Stage 2** — copia `tempo.so` sull'immagine base di DevLake

> **Il contesto di build DEVE essere la directory `backend/` del monorepo**, non questo repo. Il plugin viene copiato nel monorepo prima della build.

### 2.1 Copiare il plugin nel monorepo

```bash
cp -r "$PLUGIN_REPO/plugins/tempo/" "$DEVLAKE_MONOREPO/plugins/tempo/"
```

### 2.2 Convenzione per i tag

Usare il formato `tempo-<short-sha>` dove `<short-sha>` sono i primi 7 caratteri del commit corrente, oppure `tempo-latest` per lo snapshot:

```bash
SHORT_SHA=$(git -C "$PLUGIN_REPO" rev-parse --short=7 HEAD)
TAG="${TAG:-tempo-$SHORT_SHA}"
```

### 2.3 Build e push

```bash
cd "$DEVLAKE_MONOREPO"

docker build \
  -f "$PLUGIN_REPO/Dockerfile" \
  -t "$IMAGE_REPO:$TAG" \
  .

docker push "$IMAGE_REPO:$TAG"
```

> Se serve buildx per multi-platform: `docker buildx build --platform linux/amd64 ... --push`

### 2.4 Aggiornare anche la config-ui (opzionale)

Se si vuole allineare il tag della UI:

```bash
UI_TAG="$TAG"
```

---

## 3. Deploy nel namespace `devlake`

### 3.1 Aggiornare `helm/values.yaml`

Modificare `imageTag` e il tag della UI:

```yaml
imageTag: "tempo-<short-sha>"   # o "tempo-latest"

lake:
  image:
    repository: europe-west1-docker.pkg.dev/abs-digital-playground/apache-devlake/devlake
    pullPolicy: Always

ui:
  image:
    repository: europe-west1-docker.pkg.dev/abs-digital-playground/apache-devlake/devlake-config-ui
    tag: "tempo-<short-sha>"
    pullPolicy: Always
```

### 3.2 Helm upgrade

```bash
helm upgrade --install devlake-lake "$PLUGIN_REPO/helm/" \
  -n "$NAMESPACE" \
  --create-namespace
```

### 3.3 Verificare il pod

```bash
kubectl get pods -n devlake -l app=devlake-lake
```

Il pod deve essere in stato `Running` con `READY 1/1`.

Se `pullPolicy: Always`, il pod scaricherà la nuova immagine automaticamente dopo il rollout.

---

## 4. Verifica del plugin caricato

### 4.1 Controllare i log per il caricamento del plugin

```bash
kubectl logs -n "$NAMESPACE" -l app=devlake-lake | grep -i tempo
```

Cercare una riga tipo:

```
loading plugin: tempo from /app/bin/plugins/tempo/tempo.so
```

### 4.2 Verificare il file .so nel pod

```bash
POD=$(kubectl get pods -n "$NAMESPACE" -l app=devlake-lake -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n "$NAMESPACE" "$POD" -- ls -la /app/bin/plugins/tempo/
```

Output atteso:

```
-rwxr-xr-x  1 1010 1010  ... tempo.so
```

### 4.3 Test API — lista plugin

```bash
# Trovare la porta del servizio
kubectl get svc -n "$NAMESPACE"

# Port-forward (opzionale)
kubectl port-forward -n "$NAMESPACE" svc/devlake-lake 8080:8080 &

# Verificare che il plugin sia registrato
curl -s http://localhost:8080/plugins/tempo/connections | jq .
```

Se il plugin è caricato correttamente, il endpoint risponde (array vuoto se non ci sono connessioni).

---

## 5. Creazione connessione Tempo (API)

Le variabili dal file `.env` del repo:

```bash
source "$PLUGIN_REPO/.env"
# JIRA_TEMPO_API_KEY è ora disponibile
```

### 5.1 Creare una connessione

L'endpoint Jira/Tempo richiede:
- `name`: nome descrittivo della connessione
- `endpoint`: URL dell'istanza Jira (es. `https://your-org.atlassian.net`)
- `token`: il token API di Tempo (Bearer token)

```bash
JIRA_ENDPOINT="https://your-org.atlassian.net"

curl -s -X POST http://localhost:8080/plugins/tempo/connections \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"tempo-prod\",
    \"endpoint\": \"$JIRA_ENDPOINT\",
    \"token\": \"$JIRA_TEMPO_API_KEY\"
  }" | jq .
```

Risposta attesa: oggetto con `id` (es. `1`).

### 5.2 Testare la connessione

```bash
CONN_ID=1

curl -s -X POST "http://localhost:8080/plugins/tempo/connections/$CONN_ID/test" | jq .
```

Risposta attesa:

```json
{
  "success": true,
  "message": "success",
  "connection": { ... }
}
```

Se il test fallisce, verificare:
- Endpoint Jira accessibile dal pod
- Token API valido e non scaduto
- Il token ha permessi `Workload Management` o `Timesheets` in Tempo

### 5.3 Selezionare scope (team)

```bash
curl -s "http://localhost:8080/plugins/tempo/connections/$CONN_ID/remote-scopes" | jq .
```

Risposta: lista dei team Tempo disponibili con `teamId`, `name`, ecc.

### 5.4 Aggiungere scope

```bash
curl -s -X PUT "http://localhost:8080/plugins/tempo/connections/$CONN_ID/scopes" \
  -H "Content-Type: application/json" \
  -d '{
    "data": [
      {
        "name": "Team Name",
        "teamId": "123"
      }
    ]
  }' | jq .
```

---

## 6. Trigger pipeline e verifica dati

### 6.1 Creare una pipeline manuale

```bash
curl -s -X POST http://localhost:8080/pipelines \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"tempo-sync\",
    \"plan\": [
      [
        {
          \"plugin\": \"tempo\",
          \"subtasks\": [
            \"collectTeams\",
            \"extractTeams\",
            \"collectWorklogs\",
            \"extractWorklogs\",
            \"convertWorklogs\"
          ],
          \"options\": {
            \"connectionId\": $CONN_ID
          }
        }
      ]
    ]
  }" | jq .
```

In alternativa, creare un blueprint dal config-ui e collegarlo al cron di DevLake.

### 6.2 Monitorare la pipeline

```bash
PIPELINE_ID=<id dalla risposta precedente>

# Stato della pipeline
curl -s "http://localhost:8080/pipelines/$PIPELINE_ID" | jq '.status'

# Log dei task
curl -s "http://localhost:8080/pipelines/$PIPELINE_ID" | jq '.tasks[] | {subtask: .subtaskName, status: .status}'
```

### 6.3 Verificare i dati nel database

```bash
# Accesso MySQL
kubectl exec -n "$NAMESPACE" -it deployment/devlake-mysql -- \
  mysql -u merico -pmerico lake

# Oppure port-forward
# kubectl port-forward -n devlake svc/devlake-mysql 3306:3306 &
```

Verificare i worklog nella tabella tool layer:

```sql
SELECT COUNT(*) FROM _tool_tempo_worklogs;
SELECT * FROM _tool_tempo_worklogs LIMIT 5;
```

Verificare i team nella tabella tool layer:

```sql
SELECT COUNT(*) FROM _tool_tempo_teams;
SELECT * FROM _tool_tempo_teams LIMIT 5;
```

Verificare la mappatura nel domain layer:

```sql
SELECT COUNT(*) FROM issue_worklogs;
SELECT iw.* FROM issue_worklogs iw
JOIN _tool_tempo_worklogs tw ON iw.id = CONCAT('tempo:TempoWorklog:', tw.tempo_worklog_id)
LIMIT 5;
```

Se le tabelle sono vuote, controllare i log della pipeline per errori:

```bash
kubectl logs -n "$NAMESPACE" -l app=devlake-lake --tail=200 | grep -iE "(error|warn|tempo)"
```

---

## 7. Troubleshooting

| Problema | Possibile causa | Soluzione |
|----------|----------------|-----------|
| Pod `ImagePullBackOff` | Tag inesistente o accesso negato ad Artifact Registry | Verificare `docker pull $IMAGE_REPO:$TAG`, controllare `imagePullSecrets` |
| Plugin non caricato | File `.so` mancante o architettura errata | `kubectl exec` → `ls /app/bin/plugins/tempo/`, verificare build `linux/amd64` |
| `401 Unauthorized` da Tempo API | Token scaduto o errato | Rigenerare il token in Tempo Settings → API Integration |
| Pipeline fallisce con `connectionId is invalid` | Connessione non creata | Creare la connessione (sezione 5.1) prima di lanciare la pipeline |
| Tabelle vuote | Nessun worklog nel periodo, o scope/team non selezionato | Verificare scope e date, controllare i log del collector |
| `CGO_ENABLED=0` error | Build senza CGO | Verificare che il Dockerfile abbia `ENV CGO_ENABLED=1` |

### Verificare l'architettura del plugin

```bash
# Sul pod
kubectl exec -n "$NAMESPACE" "$POD" -- file /app/bin/plugins/tempo/tempo.so
# Output atteso: ... ELF 64-bit LSB shared object, x86-64, ...
```

### Forzare il ricaricamento del plugin

Se il pod non rileva il plugin dopo un deploy:

```bash
kubectl rollout restart deployment/devlake-lake -n "$NAMESPACE"
```

---

## 8. Rollback

Per tornare alla versione precedente:

```bash
# Ripristinare il tag precedente in values.yaml
helm upgrade --install devlake-lake "$PLUGIN_REPO/helm/" -n "$NAMESPACE"
```

Oppure specificare il tag immagine esplicitamente:

```bash
helm upgrade --install devlake-lake "$PLUGIN_REPO/helm/" \
  -n "$NAMESPACE" \
  --set lake.image.tag="previous-tag" \
  --set ui.image.tag="previous-tag"
```

---

## 9. Script automatizzato

Il repo include uno script di deploy e test automatizzato:

```bash
./scripts/deploy-test.sh
```

Vedere `scripts/deploy-test.sh` per i dettagli. Lo script supporta variabili d'ambiente per personalizzare tag, namespace e repository:

```bash
TAG=tempo-abc1234 NAMESPACE=devlake ./scripts/deploy-test.sh
```