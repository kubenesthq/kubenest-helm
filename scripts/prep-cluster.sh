#!/usr/bin/env bash
set -euo pipefail

# prep-cluster.sh — Install ingress-nginx and cert-manager on a K8s cluster
# Run this before `helm install kubenest`
#
# Usage: ./prep-cluster.sh [--email admin@example.com]

ACME_EMAIL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --email) ACME_EMAIL="$2"; shift 2 ;;
    *) ACME_EMAIL="$1"; shift ;;
  esac
done

echo "==> Checking prerequisites..."
command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found"; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "ERROR: cannot connect to cluster"; exit 1; }

echo "==> Adding Helm repos..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update

NS="kubenest-system"
echo "==> Creating namespace ${NS}..."
kubectl create namespace "$NS" 2>/dev/null || true

echo "==> Installing ingress-nginx into ${NS}..."
if helm status ingress-nginx -n "$NS" >/dev/null 2>&1; then
  echo "    ingress-nginx already installed, skipping."
else
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace "$NS" \
    --wait --timeout 5m
fi

echo "==> Installing cert-manager into ${NS}..."
if helm status cert-manager -n "$NS" >/dev/null 2>&1; then
  echo "    cert-manager already installed, skipping."
else
  helm install cert-manager jetstack/cert-manager \
    --namespace "$NS" \
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
kubectl get svc -n "$NS" ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
kubectl get svc -n "$NS" ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || \
echo "    (pending — check: kubectl get svc -n $NS)"
echo ""
echo "    Next: Point your DNS wildcard to the LB IP, then:"
echo "    helm install kubenest ./kubenest -n kubenest-system --create-namespace -f values.yaml"
