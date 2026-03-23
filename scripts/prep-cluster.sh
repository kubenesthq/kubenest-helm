#!/usr/bin/env bash
set -euo pipefail

# prep-cluster.sh — Install ingress-nginx and cert-manager on a K8s cluster
# Run this before `helm install kubenest`
#
# Usage: ./prep-cluster.sh [--email admin@example.com]

ACME_EMAIL="${1:-}"

echo "==> Checking prerequisites..."
command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found"; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "ERROR: cannot connect to cluster"; exit 1; }

echo "==> Adding Helm repos..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update

echo "==> Installing ingress-nginx..."
if helm status ingress-nginx -n ingress-nginx >/dev/null 2>&1; then
  echo "    ingress-nginx already installed, skipping."
else
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --wait --timeout 5m
fi

echo "==> Installing cert-manager..."
if helm status cert-manager -n cert-manager >/dev/null 2>&1; then
  echo "    cert-manager already installed, skipping."
else
  helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true \
    --wait --timeout 5m
fi

# Create ClusterIssuer if email provided
if [ -n "$ACME_EMAIL" ]; then
  echo "==> Creating letsencrypt-prod ClusterIssuer..."
  kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ${ACME_EMAIL}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
EOF
fi

echo ""
echo "==> Cluster is ready for KubeNest!"
echo ""
echo "    Ingress LB IP:"
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || \
echo "    (pending — check: kubectl get svc -n ingress-nginx)"
echo ""
echo "    Next: Point your DNS wildcard to the LB IP, then:"
echo "    helm install kubenest ./kubenest -n kubenest-system --create-namespace -f values.yaml"
