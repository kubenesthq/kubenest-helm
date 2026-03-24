# KubeNest Helm

Umbrella Helm chart for deploying the full KubeNest stack to a Kubernetes cluster. Single `helm install` gets you the entire platform.

## What This Deploys

| Component | Image | Port | Ingress |
|-----------|-------|------|---------|
| Backend (FastAPI) | `ghcr.io/kubenesthq/kubenest-backend` | 8000 | `api.<domain>` |
| Hub (Go WebSocket) | `ghcr.io/kubenesthq/kubenest-hub` | 8001 | `hub.<domain>` |
| UI (Next.js) | `ghcr.io/kubenesthq/kubenest-ui` | 3000 | `app.<domain>` |
| Operator (Go) | `ghcr.io/kubenesthq/operatorv2` | — | — |
| PostgreSQL (Bitnami subchart) | `bitnami/postgresql` | 5432 | — |
| Redis (Bitnami subchart) | `bitnami/redis` | 6379 | — |

## Chart Structure

```
Chart.yaml              - Dependencies: bitnami/postgresql, bitnami/redis
values.yaml             - All configurable values
templates/
  backend-deployment.yaml, backend-service.yaml, backend-ingress.yaml
  hub-deployment.yaml, hub-service.yaml, hub-ingress.yaml
  ui-deployment.yaml, ui-service.yaml, ui-ingress.yaml
  operator-deployment.yaml, operator-rbac.yaml
  secret.yaml           - JWT secret shared across backend/hub/operator
crds/                   - Operator CRDs (Workload, Project, Addon, Stack, etc.)
scripts/
  prep-cluster.sh       - Installs ingress-nginx + cert-manager prerequisites
```

## Install

```bash
# 1. Prep cluster (ingress-nginx, cert-manager)
./scripts/prep-cluster.sh --email admin@example.com

# 2. Create image pull secret (images are private on ghcr.io)
kubectl create secret docker-registry ghcr-creds \
  -n kubenest-system \
  --docker-server=ghcr.io \
  --docker-username=<user> \
  --docker-password=<pat>

# 3. Install
helm install kubenest . -n kubenest-system --create-namespace \
  --set jwtSecret=$(openssl rand -hex 32) \
  --set domain=kubenest.example.com \
  --set postgresql.auth.password=$(openssl rand -hex 16) \
  --set 'imagePullSecrets[0].name=ghcr-creds'
```

## Key Values

- `domain` — Base domain for ingress (e.g. `kubenest.example.com`)
- `jwtSecret` — Shared JWT secret for backend/hub/operator auth
- `imagePullSecrets` — List of k8s secrets for private registry auth
- `operator.gitops.*` — GitOps repo config for workload deployment via ArgoCD
- `operator.bootstrap.*` — Toggle ArgoCD/cert-manager/ingress bootstrap by operator

## Startup Order

PostgreSQL + Redis → Backend init container (alembic migrations) → Backend → Hub → Operator → UI

## Related Repos

| Repo | Path | Purpose |
|------|------|---------|
| **kubenest-backend** | `~/sb/kubenest-backend` | FastAPI control plane API |
| **kubenest-hub** | `~/sb/kubenest-hub` | Go WebSocket message broker |
| **kubenest-operator** | `~/sb/op3` | Go Kubernetes operator (has its own standalone chart at `charts/kubenest-operator/`) |
| **kubenest-ui** | `~/sb/kubenest-ui` | Next.js frontend |
| **kubenest-contracts** | `~/sb/kubenest-contracts` | Shared schemas and event definitions |

**Dependency flow:** Backend ↔ Hub ↔ Operator. Shared JWT secret ties them together.

## Notes

- The operator also has a **standalone chart** in `op3/charts/kubenest-operator/` for deploying to remote target clusters separately. This umbrella chart bakes the operator in as a template for the single-cluster model.
- GHCR images are private — `imagePullSecrets` is required.
- Bitnami subcharts rotate image tags aggressively — if PostgreSQL/Redis fail with "not found", bump the subchart versions in `Chart.yaml` and run `helm dependency update`.
