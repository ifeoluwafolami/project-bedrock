#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT_DIR/terraform}"
NAMESPACE="${NAMESPACE:-retail-app}"
CHART_VERSION="${CHART_VERSION:-1.6.1}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need aws
need helm
need jq
need kubectl
need terraform

tf_output() {
  terraform -chdir="$TF_DIR" output -raw "$1"
}

REGION="$(tf_output region)"
MYSQL_SECRET_ARN="$(tf_output mysql_secret_arn)"
POSTGRES_SECRET_ARN="$(tf_output postgres_secret_arn)"
DYNAMODB_TABLE="$(tf_output dynamodb_table_name)"
CARTS_ROLE_ARN="$(tf_output carts_dynamodb_role_arn)"

MYSQL_SECRET_JSON="$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "$MYSQL_SECRET_ARN" \
  --query SecretString \
  --output text)"

POSTGRES_SECRET_JSON="$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "$POSTGRES_SECRET_ARN" \
  --query SecretString \
  --output text)"

MYSQL_HOST="$(jq -r '.host' <<<"$MYSQL_SECRET_JSON")"
MYSQL_PORT="$(jq -r '.port' <<<"$MYSQL_SECRET_JSON")"
MYSQL_DB="$(jq -r '.dbname' <<<"$MYSQL_SECRET_JSON")"
MYSQL_USER="$(jq -r '.username' <<<"$MYSQL_SECRET_JSON")"
MYSQL_PASSWORD="$(jq -r '.password' <<<"$MYSQL_SECRET_JSON")"

POSTGRES_HOST="$(jq -r '.host' <<<"$POSTGRES_SECRET_JSON")"
POSTGRES_PORT="$(jq -r '.port' <<<"$POSTGRES_SECRET_JSON")"
POSTGRES_DB="$(jq -r '.dbname' <<<"$POSTGRES_SECRET_JSON")"
POSTGRES_USER="$(jq -r '.username' <<<"$POSTGRES_SECRET_JSON")"
POSTGRES_PASSWORD="$(jq -r '.password' <<<"$POSTGRES_SECRET_JSON")"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat >"$TMP_DIR/catalog-values.yaml" <<EOF_VALUES
app:
  persistence:
    provider: mysql
    endpoint: "${MYSQL_HOST}:${MYSQL_PORT}"
    database: "${MYSQL_DB}"
    secret:
      username: "${MYSQL_USER}"
      password: "${MYSQL_PASSWORD}"
mysql:
  create: false
EOF_VALUES

cat >"$TMP_DIR/carts-values.yaml" <<EOF_VALUES
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "${CARTS_ROLE_ARN}"
app:
  persistence:
    provider: dynamodb
    dynamodb:
      tableName: "${DYNAMODB_TABLE}"
      createTable: false
dynamodb:
  create: false
EOF_VALUES

cat >"$TMP_DIR/orders-values.yaml" <<EOF_VALUES
app:
  persistence:
    provider: postgres
    endpoint: "${POSTGRES_HOST}:${POSTGRES_PORT}"
    database: "${POSTGRES_DB}"
    secret:
      username: "${POSTGRES_USER}"
      password: "${POSTGRES_PASSWORD}"
  messaging:
    provider: rabbitmq
    rabbitmq:
      addresses:
        - rabbitmq:5672
      secret:
        username: guest
        password: guest
postgresql:
  create: false
rabbitmq:
  create: true
EOF_VALUES

cat >"$TMP_DIR/checkout-values.yaml" <<EOF_VALUES
app:
  persistence:
    provider: redis
  endpoints:
    orders: http://orders:80
redis:
  create: true
EOF_VALUES

cat >"$TMP_DIR/ui-values.yaml" <<EOF_VALUES
app:
  endpoints:
    catalog: http://catalog:80
    carts: http://carts:80
    checkout: http://checkout:80
    orders: http://orders:80
ingress:
  enabled: true
  className: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health/liveness
EOF_VALUES

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate namespace "$NAMESPACE" \
  instrumentation.opentelemetry.io/inject-java- \
  instrumentation.opentelemetry.io/inject-nodejs- \
  instrumentation.opentelemetry.io/inject-python- \
  instrumentation.opentelemetry.io/inject-dotnet- \
  --overwrite >/dev/null 2>&1 || true

helm upgrade --install catalog oci://public.ecr.aws/aws-containers/retail-store-sample-catalog-chart \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --set resources.requests.cpu=64m \
  --set resources.requests.memory=128Mi \
  --set resources.limits.memory=192Mi \
  --values "$TMP_DIR/catalog-values.yaml" \
  --wait

helm upgrade --install carts oci://public.ecr.aws/aws-containers/retail-store-sample-cart-chart \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --set resources.requests.cpu=64m \
  --set resources.requests.memory=256Mi \
  --set resources.limits.memory=384Mi \
  --values "$TMP_DIR/carts-values.yaml" \
  --wait

helm upgrade --install orders oci://public.ecr.aws/aws-containers/retail-store-sample-orders-chart \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --set resources.requests.cpu=64m \
  --set resources.requests.memory=384Mi \
  --set resources.limits.memory=512Mi \
  --values "$TMP_DIR/orders-values.yaml" \
  --wait

helm upgrade --install checkout oci://public.ecr.aws/aws-containers/retail-store-sample-checkout-chart \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --set resources.requests.cpu=64m \
  --set resources.requests.memory=128Mi \
  --set resources.limits.memory=192Mi \
  --values "$TMP_DIR/checkout-values.yaml" \
  --wait

helm upgrade --install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --set resources.requests.cpu=64m \
  --set resources.requests.memory=256Mi \
  --set resources.limits.memory=384Mi \
  --values "$TMP_DIR/ui-values.yaml" \
  --wait

kubectl rollout status deployment/catalog -n "$NAMESPACE" --timeout=300s
kubectl rollout status deployment/carts -n "$NAMESPACE" --timeout=300s
kubectl rollout status deployment/orders -n "$NAMESPACE" --timeout=300s
kubectl rollout status deployment/checkout -n "$NAMESPACE" --timeout=300s
kubectl rollout status deployment/ui -n "$NAMESPACE" --timeout=300s

echo
echo "Retail app is deployed in namespace: $NAMESPACE"
echo "Run this until ADDRESS is populated:"
echo "kubectl get ingress ui -n $NAMESPACE"
