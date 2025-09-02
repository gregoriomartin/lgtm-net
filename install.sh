#!/bin/bash

set -e

NAMESPACE=${1:-monitoring}
SKIP_PREREQ=${2:-false}

echo
echo "========================================"
echo "LGTM Stack Installation Script"
echo "========================================"
echo
echo "Installing to namespace: $NAMESPACE"

if [[ "$SKIP_PREREQ" != "true" ]]; then
    echo
    echo "========================================"
    echo "Checking Prerequisites"
    echo "========================================"
    echo
    
    MISSING_TOOLS=()
    
    echo "Checking for kubectl..."
    if ! command -v kubectl &> /dev/null; then
        echo "   kubectl is not installed or not in PATH"
        echo "    Install: https://kubernetes.io/docs/tasks/tools/"
        MISSING_TOOLS+=("kubectl")
    else
        echo "   kubectl is installed: $(kubectl version --client --short)"
    fi
    
    echo "Checking for helm..."
    if ! command -v helm &> /dev/null; then
        echo "   helm is not installed or not in PATH"
        echo "    Install: https://helm.sh/docs/intro/install/"
        MISSING_TOOLS+=("helm")
    else
        echo "   helm is installed: $(helm version --short)"
    fi
    
    echo "Checking Kubernetes cluster connectivity..."
    if ! kubectl cluster-info &> /dev/null; then
        echo "   Cannot connect to Kubernetes cluster"
        echo "    Configure: https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/"
        MISSING_TOOLS+=("kubernetes-connection")
    else
        echo "   Connected to Kubernetes cluster"
    fi
    
    if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
        echo
        echo "Prerequisites check failed!"
        exit 1
    fi
    
    echo
    echo " All prerequisites met!"
fi

echo
echo "========================================"
echo "Adding Helm Repositories"
echo "========================================"
echo

echo "Adding prometheus-community repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
echo "   Added prometheus-community repository"

echo "Adding grafana repository..."
helm repo add grafana https://grafana.github.io/helm-charts
echo "   Added grafana repository"

echo "Updating Helm repositories..."
helm repo update
echo "   Repositories updated"

echo
echo "========================================"
echo "Creating Namespace"
echo "========================================"
echo

echo "Checking if namespace '$NAMESPACE' exists..."
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "  Namespace '$NAMESPACE' already exists"
else
    echo "Creating namespace '$NAMESPACE'..."
    kubectl create namespace "$NAMESPACE"
    echo "   Created namespace '$NAMESPACE'"
fi

echo
echo "========================================"
echo "Installing Prometheus Operator"
echo "========================================"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMETHEUS_VALUES="$SCRIPT_DIR/helm-values/prometheus.yaml"

if [[ -f "$PROMETHEUS_VALUES" ]]; then
    VALUES_PARAM="-f $PROMETHEUS_VALUES"
else
    echo "  prometheus.yaml not found, using default values"
    VALUES_PARAM=""
fi

echo "Installing Prometheus Operator..."
helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack \
    --version 66.3.1 \
    -n "$NAMESPACE" \
    $VALUES_PARAM \
    --wait --timeout 10m

echo "   Prometheus Operator installed successfully"

echo
echo "========================================"
echo "Installing LGTM Stack"
echo "========================================"
echo

LGTM_VALUES="$SCRIPT_DIR/helm-values/lgtm.yaml"

if [[ -f "$LGTM_VALUES" ]]; then
    VALUES_PARAM="-f $LGTM_VALUES"
else
    echo "  lgtm.yaml not found, using default values"
    VALUES_PARAM=""
fi

echo "Installing LGTM Stack (this may take several minutes)..."
helm upgrade --install lgtm grafana/lgtm-distributed \
    --version 2.1.0 \
    -n "$NAMESPACE" \
    $VALUES_PARAM \
    --wait --timeout 15m

echo "   LGTM Stack installed successfully"

echo
echo "========================================"
echo "Deploying Additional Components"
echo "========================================"
echo

MANIFESTS_PATH="$SCRIPT_DIR/manifests"

OTEL_FILE="$MANIFESTS_PATH/otel-collector.yaml"
if [[ -f "$OTEL_FILE" ]]; then
    echo "Deploying OpenTelemetry Collector..."
    kubectl apply -f "$OTEL_FILE"
    echo "   OpenTelemetry Collector deployed"
fi

ALLOY_FILE="$MANIFESTS_PATH/alloy.yaml"
if [[ -f "$ALLOY_FILE" ]]; then
    echo "Deploying Alloy..."
    kubectl apply -f "$ALLOY_FILE"
    echo "   Alloy deployed"
fi

echo
echo "========================================"
echo "Building and Deploying Logging Application"
echo "========================================"
echo

SRC_PATH="$SCRIPT_DIR/src"
if [[ -d "$SRC_PATH" ]]; then
    echo "Building Docker image from src folder..."
    
    cd "$SRC_PATH"
    docker build -t logging-app:latest .
    cd - > /dev/null
    
    echo "   Docker image built successfully"
else
    echo "   src folder not found"
    exit 1
fi

APP_PATH="$MANIFESTS_PATH/app"
LOGGING_APP_FILE="$APP_PATH/logging-app.yaml"
if [[ -f "$LOGGING_APP_FILE" ]]; then
    echo "Deploying logging application..."
    kubectl apply -f "$LOGGING_APP_FILE"
    echo "   Logging application deployed"
else
    echo "   logging-app.yaml not found in manifests/app/"
    exit 1
fi

PODMONITOR_FILE="$APP_PATH/podmonitor.yaml"
if [[ -f "$PODMONITOR_FILE" ]]; then
    echo "Deploying PodMonitor for metrics collection..."
    kubectl apply -f "$PODMONITOR_FILE"
    echo "   PodMonitor deployed"
else
    echo "   podmonitor.yaml not found in manifests/app/"
    exit 1
fi

echo
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo

echo "The LGTM Stack has been successfully installed!"
echo
echo "Next steps:"
echo "  1. Get Grafana admin password:"
echo "     kubectl get secret --namespace $NAMESPACE lgtm-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode"
echo
echo "  2. Access Grafana:"
echo "     kubectl port-forward svc/lgtm-grafana 3000:80 -n $NAMESPACE"
echo "     Open browser: http://localhost:3000"
echo "     Username: admin"
echo
echo "  3. Test services:"
echo "     ./test-services.sh"