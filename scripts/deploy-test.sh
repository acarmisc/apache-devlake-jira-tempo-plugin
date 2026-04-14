#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
DEVLAKE_MONOREPO="${DEVLAKE_MONOREPO:-$HOME/Projects/apache-devlake/backend}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_REPO="${IMAGE_REPO:-europe-west1-docker.pkg.dev/abs-digital-playground/apache-devlake/devlake}"
NAMESPACE="${NAMESPACE:-devlake}"
HELM_RELEASE="${HELM_RELEASE:-devlake-lake}"
SHORT_SHA="$(git -C "$PLUGIN_REPO" rev-parse --short=7 HEAD 2>/dev/null || echo 'unknown')"
TAG="${TAG:-tempo-$SHORT_SHA}"
SKIP_PUSH="${SKIP_PUSH:-false}"
SKIP_DEPLOY="${SKIP_DEPLOY:-false}"
SKIP_TEST="${SKIP_TEST:-false}"
PORT="${PORT:-8080}"
JIRA_ENDPOINT="${JIRA_ENDPOINT:-}"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()  { echo -e "${GREEN}==> $*${NC}"; }

# ─── Cleanup ─────────────────────────────────────────────────────────────────
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        error "Script failed at step with exit code $exit_code"
        error "Check the output above for details."
    fi
    # Kill port-forward if running
    if [ -n "${PF_PID:-}" ]; then
        kill "$PF_PID" 2>/dev/null || true
    fi
    exit $exit_code
}
trap cleanup EXIT

# ─── Prerequisites check ────────────────────────────────────────────────────
check_prerequisites() {
    step "Checking prerequisites..."

    local missing=0

    if ! command -v docker &>/dev/null; then
        error "docker not found"
        missing=1
    fi

    if ! command -v kubectl &>/dev/null; then
        error "kubectl not found"
        missing=1
    fi

    if ! command -v helm &>/dev/null; then
        error "helm not found"
        missing=1
    fi

    if [ ! -d "$DEVLAKE_MONOREPO" ]; then
        error "DevLake monorepo not found at $DEVLAKE_MONOREPO"
        error "Set DEVLAKE_MONOREPO to the backend/ directory path"
        missing=1
    fi

    if [ ! -d "$PLUGIN_REPO/plugins/tempo" ]; then
        error "Plugin source not found at $PLUGIN_REPO/plugins/tempo"
        missing=1
    fi

    if [ ! -f "$PLUGIN_REPO/Dockerfile" ]; then
        error "Dockerfile not found at $PLUGIN_REPO/Dockerfile"
        missing=1
    fi

    if [ ! -f "$PLUGIN_REPO/.env" ]; then
        warn ".env file not found at $PLUGIN_REPO/.env — API tests will be skipped"
    fi

    if [ $missing -ne 0 ]; then
        error "Prerequisites check failed. Install missing tools and verify paths."
        exit 1
    fi

    info "All prerequisites met"
}

# ─── Step 1: Copy plugin to monorepo ─────────────────────────────────────────
copy_plugin() {
    step "Copying plugin to monorepo..."

    local dest="$DEVLAKE_MONOREPO/plugins/tempo"
    rm -rf "$dest"
    cp -r "$PLUGIN_REPO/plugins/tempo/" "$dest"

    info "Plugin copied to $dest"
}

# ─── Step 2: Build Docker image ──────────────────────────────────────────────
build_image() {
    step "Building Docker image $IMAGE_REPO:$TAG..."

    cd "$DEVLAKE_MONOREPO"

    docker build \
        -f "$PLUGIN_REPO/Dockerfile" \
        -t "$IMAGE_REPO:$TAG" \
        --platform linux/amd64 \
        .

    info "Image built successfully"

    if [ "$SKIP_PUSH" = "false" ]; then
        step "Pushing image to registry..."
        docker push "$IMAGE_REPO:$TAG"
        info "Image pushed: $IMAGE_REPO:$TAG"
    else
        warn "SKIP_PUSH=true — skipping docker push"
    fi
}

# ─── Step 3: Update helm values ──────────────────────────────────────────────
update_helm_values() {
    step "Updating helm/values.yaml with tag $TAG..."

    local values="$PLUGIN_REPO/helm/values.yaml"

    if [ ! -f "$values" ]; then
        error "values.yaml not found at $values"
        exit 1
    fi

    sed -i.bak "s/^imageTag:.*/imageTag: \"$TAG\"/" "$values"
    sed -i.bak "s/^    tag:.*/    tag: \"$TAG\"/" "$values"
    rm -f "$values.bak"

    info "values.yaml updated"
}

# ─── Step 4: Deploy ──────────────────────────────────────────────────────────
deploy() {
    step "Deploying $HELM_RELEASE to namespace $NAMESPACE..."

    helm upgrade --install "$HELM_RELEASE" "$PLUGIN_REPO/helm/" \
        -n "$NAMESPACE" \
        --create-namespace \
        --wait

    info "Helm release deployed"
}

# ─── Step 5: Wait for rollout ────────────────────────────────────────────────
wait_for_rollout() {
    step "Waiting for deployment rollout..."

    kubectl rollout status deployment/devlake-lake \
        -n "$NAMESPACE" \
        --timeout=300s

    info "Deployment is ready"
}

# ─── Step 6: Smoke tests ─────────────────────────────────────────────────────
smoke_test() {
    step "Running smoke tests..."

    local pod
    pod="$(kubectl get pods -n "$NAMESPACE" -l app=devlake-lake -o jsonpath='{.items[0].metadata.name}')"

    if [ -z "$pod" ]; then
        error "No pod found for devlake-lake"
        exit 1
    fi

    info "Pod: $pod"

    # Check plugin .so file exists
    step "  Checking tempo.so exists in pod..."
    if kubectl exec -n "$NAMESPACE" "$pod" -- test -f /app/bin/plugins/tempo/tempo.so 2>/dev/null; then
        info "  tempo.so found in pod"
    else
        error "  tempo.so NOT found in pod"
        exit 1
    fi

    # Check plugin loaded in logs
    step "  Checking plugin loaded in logs..."
    if kubectl logs -n "$NAMESPACE" "$pod" --tail=500 | grep -qi "tempo"; then
        info "  Tempo plugin detected in logs"
    else
        warn "  Tempo plugin not found in recent logs (may need more lines)"
    fi

    # Port-forward and test API
    step "  Setting up port-forward on port $PORT..."
    kubectl port-forward -n "$NAMESPACE" svc/devlake-lake "$PORT:8080" >/dev/null 2>&1 &
    PF_PID=$!
    sleep 3

    step "  Checking Tempo API endpoint..."
    local http_code
    http_code="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/plugins/tempo/connections" 2>/dev/null || echo '000')"

    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        info "  Tempo API endpoint reachable (HTTP $http_code)"
    else
        warn "  Tempo API returned HTTP $http_code — plugin may not be loaded yet"
    fi
}

# ─── Step 7: Create connection and test ──────────────────────────────────────
test_tempo_connection() {
    step "Testing Tempo API connection..."

    if [ ! -f "$PLUGIN_REPO/.env" ]; then
        warn ".env file not found — skipping connection test"
        return 0
    fi

    # Source .env
    set -a
    source "$PLUGIN_REPO/.env"
    set +a

    if [ -z "${JIRA_TEMPO_API_KEY:-}" ]; then
        warn "JIRA_TEMPO_API_KEY not set in .env — skipping connection test"
        return 0
    fi

    if [ -z "$JIRA_ENDPOINT" ]; then
        warn "JIRA_ENDPOINT not set — set it to your Jira URL (e.g., https://your-org.atlassian.net)"
        warn "Skipping connection creation"
        return 0
    fi

    local base_url="http://localhost:$PORT"

    # Create connection
    step "  Creating Tempo connection..."
    local conn_response
    conn_response="$(curl -s -X POST "$base_url/plugins/tempo/connections" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"tempo-prod\",
            \"endpoint\": \"$JIRA_ENDPOINT\",
            \"token\": \"$JIRA_TEMPO_API_KEY\"
        }")"

    local conn_id
    conn_id="$(echo "$conn_response" | jq -r '.id // empty' 2>/dev/null || true)"

    if [ -z "$conn_id" ]; then
        warn "  Failed to create connection. Response:"
        echo "$conn_response" | jq . 2>/dev/null || echo "$conn_response"
        return 0
    fi

    info "  Connection created with ID: $conn_id"

    # Test connection
    step "  Testing connection $conn_id..."
    local test_response
    test_response="$(curl -s -X POST "$base_url/plugins/tempo/connections/$conn_id/test")"

    local test_success
    test_success="$(echo "$test_response" | jq -r '.success // empty' 2>/dev/null || echo "false")"

    if [ "$test_success" = "true" ]; then
        info "  Connection test PASSED"
    else
        warn "  Connection test FAILED. Response:"
        echo "$test_response" | jq . 2>/dev/null || echo "$test_response"
    fi

    # List remote scopes (teams)
    step "  Listing remote scopes (teams)..."
    local scopes_response
    scopes_response="$(curl -s "$base_url/plugins/tempo/connections/$conn_id/remote-scopes")"
    echo "$scopes_response" | jq . 2>/dev/null || echo "$scopes_response"

    info "Connection test complete (conn_id=$conn_id)"
}

# ─── Step 8: Verify data ─────────────────────────────────────────────────────
verify_data() {
    step "Verifying database tables..."

    local mysql_pod
    mysql_pod="$(kubectl get pods -n "$NAMESPACE" -l app=devlake-mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

    if [ -z "$mysql_pod" ]; then
        # Try alternative label
        mysql_pod="$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
    fi

    if [ -z "$mysql_pod" ]; then
        warn "MySQL pod not found — skipping database verification"
        warn "You can verify manually:"
        warn "  kubectl exec -n $NAMESPACE <mysql-pod> -- mysql -u merico -pmerico lake -e 'SELECT COUNT(*) FROM _tool_tempo_worklogs;'"
        return 0
    fi

    info "  MySQL pod: $mysql_pod"

    step "  Checking _tool_tempo_worklogs..."
    kubectl exec -n "$NAMESPACE" "$mysql_pod" -- \
        mysql -u merico -pmerico lake \
        -e "SELECT COUNT(*) AS worklog_count FROM _tool_tempo_worklogs;" 2>/dev/null || \
        warn "  Table _tool_tempo_worklogs not found (may need to run a pipeline first)"

    step "  Checking _tool_tempo_teams..."
    kubectl exec -n "$NAMESPACE" "$mysql_pod" -- \
        mysql -u merico -pmerico lake \
        -e "SELECT COUNT(*) AS team_count FROM _tool_tempo_teams;" 2>/dev/null || \
        warn "  Table _tool_tempo_teams not found (may need to run a pipeline first)"
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo "======================================"
    echo " Tempo Plugin Deploy & Test Pipeline"
    echo " Tag: $TAG"
    echo " Namespace: $NAMESPACE"
    echo "======================================"
    echo ""

    check_prerequisites

    copy_plugin

    if [ "$SKIP_DEPLOY" = "true" ]; then
        warn "SKIP_DEPLOY=true — building image only"
        build_image
        echo ""
        info "Build complete. Image: $IMAGE_REPO:$TAG"
        info "To deploy, run without SKIP_DEPLOY or do manually:"
        info "  helm upgrade --install $HELM_RELEASE $PLUGIN_REPO/helm/ -n $NAMESPACE"
        exit 0
    fi

    build_image
    update_helm_values
    deploy
    wait_for_rollout

    if [ "$SKIP_TEST" = "false" ]; then
        smoke_test
        test_tempo_connection
        verify_data
    else
        warn "SKIP_TEST=true — skipping tests"
    fi

    echo ""
    echo "======================================"
    info "Deploy complete!"
    info "Image:  $IMAGE_REPO:$TAG"
    info "Pod:    kubectl get pods -n $NAMESPACE -l app=devlake-lake"
    info "Logs:   kubectl logs -n $NAMESPACE -l app=devlake-lake | grep -i tempo"
    echo "======================================"
}

main "$@"