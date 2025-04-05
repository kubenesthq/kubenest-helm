# Kubenest Helm Chart

This Helm chart packages multiple Kubernetes components into a single umbrella chart. It includes:

- Ingress Controller (optional)
- Cert Manager (optional)
- Container Registry (optional)
- Kubenest Operator (mandatory)
- Buildwatch (mandatory)

## Prerequisites

- Kubernetes cluster 1.16+
- Helm 3.0+

## Installation

1. Add the required Helm repositories:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add twun https://helm.twun.io
helm repo add kubenest oci://ghcr.io/kubenesthq/charts
helm repo update
```

2. Create a values file with your configuration:

```yaml
# Shared configuration
tld: "your-domain.com"
email: "your-email@example.com"

# Mandatory components
shapeblock-operator:
  image:
    tag: "05-04-2025.09.57"
  apiUrl: "https://your-api-url"
  credentials:
    apiKey: "your-cluster-key"
    licenseKey: "your-license-key"
    licenseEmail: "your-email@example.com"
  imported: true

buildwatch:
  config:
    backendURL: "https://your-api-url"
    clusterKey: "your-cluster-key"

# Optional components
ingress:
  enabled: true

certManager:
  enabled: true

registry:
  enabled: true
```

3. Download the chart dependencies:

```bash
helm dependency build
```

4. Install the chart:

```bash
# Option 1: Using values file
helm install kubenest oci://ghcr.io/kubenesthq/charts/kubenest -f values.yaml -n your-namespace --include-crds

# Option 2: Using CLI values
helm install kubenest oci://ghcr.io/kubenesthq/charts/kubenest \
  --set shapeblock-operator.image.tag=05-04-2025.10.32 \
  --set shapeblock-operator.credentials.apiKey=your-cluster-key \
  --set buildwatch.config.clusterKey=your-cluster-key \
  -n your-namespace \
  --include-crds

# Option 3: Using both values file and CLI overrides
helm install kubenest ./kubenest \
  -f values.yaml \
  --set shapeblock-operator.credentials.apiKey=your-cluster-key \
  --set buildwatch.config.clusterKey=your-cluster-key \
  -n your-namespace \
  --include-crds
```

## Configuration

The following table lists the configurable parameters of the chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tld` | Top-level domain for ingress hosts | `kubenestapp.com` |
| `email` | Email for cert-manager | `admin@example.com` |
| `shapeblock-operator.image.tag` | Version of the operator to deploy | `"05-04-2025.09.57"` |
| `shapeblock-operator.apiUrl` | API URL for the operator | `""` |
| `shapeblock-operator.credentials.apiKey` | API key for the operator | `""` |
| `shapeblock-operator.credentials.licenseKey` | License key for the operator | `""` |
| `shapeblock-operator.credentials.licenseEmail` | License email for the operator | `""` |
| `buildwatch.config.backendURL` | Backend URL for Buildwatch | `""` |
| `buildwatch.config.clusterKey` | Cluster key for Buildwatch | `""` |
| `ingress.enabled` | Enable Ingress Controller | `false` |
| `certManager.enabled` | Enable Cert Manager | `false` |
| `registry.enabled` | Enable Container Registry | `false` |

## Dependencies

The chart has the following dependencies that are conditionally included based on the values:

- nginx-ingress-controller (from bitnami) - enabled when `ingress.enabled` is true
- cert-manager (from bitnami) - enabled when `certManager.enabled` is true
- docker-registry (from twun) - enabled when `registry.enabled` is true
- shapeblock-operator (from kubenest) - always included (mandatory)
- buildwatch (from kubenest) - always included (mandatory)

## Notes

- The operator and buildwatch components are mandatory and will always be installed
- Other components can be enabled/disabled as needed
- Make sure to provide all required credentials and URLs in the values file
- The chart uses Helm's native dependency management for conditional installation of components
- All components will be installed in the namespace specified during helm install (via `-n` flag)
- When using `helm template`, include the `--include-crds` flag to generate CRD manifests

## Testing

```bash
helm template . -f sample-values.yaml --output-dir ./output --include-crds
```

## Packaging and Publishing to GitHub Packages

1. Login to GitHub Container Registry:

```bash
echo $GITHUB_TOKEN | helm registry login ghcr.io -u USERNAME --password-stdin
```

2. Package the chart:

```bash
helm package .
```

3. Push the chart to GitHub Packages:

```bash
# For the first version
helm push kubenest-0.1.0.tgz oci://ghcr.io/kubenesthq/charts

# For subsequent versions, increment the version in Chart.yaml and repeat
helm push kubenest-0.1.1.tgz oci://ghcr.io/kubenesthq/charts
```

4. To use the published chart:

```bash
# Option 1: Using repository (recommended for frequent updates)
# Add the repository
helm repo add kubenesthq oci://ghcr.io/kubenesthq/charts

# Update the repository
helm repo update

# Install the chart
helm install kubenest kubenesthq/kubenest -f values.yaml -n your-namespace --include-crds

# Option 2: Direct OCI installation (useful for one-time installations)
helm install kubenest oci://ghcr.io/kubenesthq/charts/kubenest -f values.yaml -n your-namespace --include-crds
```
