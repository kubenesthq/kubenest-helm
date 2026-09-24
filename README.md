# KubeNest control-plane Helm chart

One chart, one cluster. `kubenest/kubenest` installs the KubeNest **control
plane** into a single Kubernetes cluster:

| Component | What it is |
|-----------|------------|
| backend | FastAPI control-plane API (Deployment + Service + ServiceAccount/Role) |
| hub | Operator WebSocket relay (Deployment + Service) |
| ui | Next.js admin UI (Deployment + Service) |
| postgresql | Bitnami PostgreSQL subchart, image pinned by digest |
| redis | Bitnami Redis subchart (standalone), image pinned by digest |
| Gateway + Certificate + HTTPRoutes | Gateway API exposure for `app.`, `api.` and `hub.<domain>` |

The **operator is not installed by this chart**. The platform bundle is the only
operator source: this chart installs into a cluster where the bundle already runs
the operator, and that operator creates its workload Argo CD Applications on its
own cluster, against its own Argo CD.

## What the cluster must already have

Installed by the KubeNest platform bundle (see `kubenest-contracts`):

- Traefik with the Gateway API CRDs, exposing a GatewayClass named `traefik`.
  The chart's own Gateway listens on port **8443**, which is the bundle
  Traefik's `websecure` entrypoint port — not 443.
- cert-manager with a ClusterIssuer named `kubenest-ca`, which signs the
  control-plane certificate from the platform CA.
- A default StorageClass for the PostgreSQL and Redis volumes.
- Kubernetes 1.29+ and Helm 3.8+.

No network access is needed to install from this checkout: the PostgreSQL and
Redis chart archives are vendored under `kubenest/charts/`.

## Which command installs it

`kubenest platform install --control-plane` installs the platform bundle *and*
this chart into the first cluster, then registers that cluster through the same
API path as every other cluster and leaves the CLI logged in. Every further
cluster is added with `kubenest platform install`, using the values the CLI
already holds.

## Required values

The installer generates these; the chart refuses to render without them.

| Value | Notes |
|-------|-------|
| `domain` | Hostnames become `app.<domain>`, `api.<domain>`, `hub.<domain>` |
| `jwtSecret` | `openssl rand -hex 32`; shared by backend and hub |
| `encryptionKey` | Fernet key for credentials stored at rest |
| `postgresql.auth.password` | Database password |
| `backend.admin.email` | Initial admin account, created by the backend on first boot |
| `backend.admin.password` | Created admin's password; no default |

Optional, with defaults: `gateway.enabled` (`true`), `gateway.className`
(`traefik`), `gateway.issuer` (`kubenest-ca`), `gateway.port` (`8443`),
`backend.crudAdmin.enabled` (`false`), `hub.publicURL` (`wss://hub.<domain>`),
`provisioningCallbackSecret`, `imagePullSecrets` and the per-component image,
replica and resource settings.

## Rendering locally

```bash
helm template kubenest-cp ./kubenest -n kubenest-system -f ./kubenest/sample-values.yaml
```

`kubenest/sample-values.yaml` is a minimal example of what the installer writes.

## Packaging and publishing

```bash
helm package kubenest
helm push kubenest-3.0.0.tgz oci://ghcr.io/kubenesthq/charts
```

Bump `version` in `Chart.yaml` before pushing; the version is what the platform
bundle and the CLI pin.

## Dependency lock

`Chart.lock` pins the two Bitnami subcharts by version and digest. It was
regenerated with:

```bash
helm dependency update kubenest
```

Regenerating it needs the Bitnami repository (`helm repo add bitnami
https://charts.bitnami.com/bitnami`) and downloads the same archives that are
vendored in `kubenest/charts/`.
