#!/bin/bash

# LGTM Stack Installation Script for Linux/Mac
# Installs Loki, Grafana, Tempo, Mimir with Prometheus Operator

set -e

# Default values
NAMESPACE="monitoring"
SKIP_PREREQUISITES=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --skip-prerequisites)
            SKIP_PREREQUISITES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -n, --namespace NAME     Kubernetes namespace (default: monitoring)"
            echo "  --skip-prerequisites     Skip prerequisite checks"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Helper functions
print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_info() {
    echo -e "${CYAN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_header() {
    echo ""
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}========================================${NC}"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check kubectl
    print_info "Checking for kubectl..."
    if command -v kubectl &> /dev/null; then
        local kubectl_version=$(kubectl version --short 2>/dev/null | head -n1)
        print_success "  ✓ kubectl is installed: $kubectl_version"
    else
        print_error "  ✗ kubectl is not installed or not in PATH"
        print_warning "    Description: Kubernetes CLI tool for managing clusters"
        missing_tools+=("kubectl")
    fi
    
    # Check helm
    print_info "Checking for helm..."
    if command -v helm &> /dev/null; then
        local helm_version=$(helm version --short 2>/dev/null)
        print_success "  ✓ helm is installed: $helm_version"
    else
        print_error "  ✗ helm is not installed or not in PATH"
        print_warning "    Description: Kubernetes package manager"
        missing_tools+=("helm")
    fi
    
    # Check Kubernetes connectivity
    print_info "Checking Kubernetes cluster connectivity..."
    if kubectl cluster-info &> /dev/null; then
        print_success "  ✓ Connected to Kubernetes cluster"
        kubectl version --short 2>/dev/null
    else
        print_error "  ✗ Cannot connect to Kubernetes cluster"
        print_warning "    Ensure you have a valid kubeconfig and cluster access"
        missing_tools+=("kubernetes-connection")
    fi
    
    # Check if any tools are missing
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo ""
        print_error "Prerequisites check failed!"
        echo ""
        echo -e "${YELLOW}Installation instructions:${NC}"
        
        for tool in "${missing_tools[@]}"; do
            case $tool in
                kubectl)
                    echo "  kubectl: https://kubernetes.io/docs/tasks/tools/"
                    ;;
                helm)
                    echo "  helm: https://helm.sh/docs/intro/install/"
                    ;;
                kubernetes-connection)
                    echo "  Configure kubectl: https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/"
                    ;;
            esac
        done
        
        exit 1
    fi
    
    print_success "\n✓ All prerequisites met!"
}

# Add Helm repositories
add_helm_repositories() {
    print_header "Adding Helm Repositories"
    
    declare -A repositories=(
        ["prometheus-community"]="https://prometheus-community.github.io/helm-charts"
        ["grafana"]="https://grafana.github.io/helm-charts"
    )
    
    for repo in "${!repositories[@]}"; do
        print_info "Adding $repo repository..."
        if helm repo add "$repo" "${repositories[$repo]}" 2>/dev/null; then
            print_success "  ✓ Added $repo repository"
        else
            print_warning "  Repository $repo already exists, updating..."
        fi
    done
    
    print_info "Updating Helm repositories..."
    helm repo update
    print_success "  ✓ Repositories updated"
}

# Create namespace
create_namespace() {
    print_header "Creating Namespace"
    
    print_info "Checking if namespace '$NAMESPACE' exists..."
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warning "  Namespace '$NAMESPACE' already exists"
    else
        print_info "Creating namespace '$NAMESPACE'..."
        kubectl create namespace "$NAMESPACE"
        print_success "  ✓ Created namespace '$NAMESPACE'"
    fi
}

# Install Prometheus Operator
install_prometheus_operator() {
    print_header "Installing Prometheus Operator"
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local values_file="$script_dir/../helm/values-prometheus.yaml"
    
    local values_param=""
    if [ -f "$values_file" ]; then
        values_param="-f $values_file"
    else
        print_warning "  values-prometheus.yaml not found, using default values"
    fi
    
    print_info "Installing Prometheus Operator..."
    helm upgrade --install prometheus-operator \
        prometheus-community/kube-prometheus-stack \
        --version 66.3.1 \
        -n "$NAMESPACE" \
        $values_param \
        --wait \
        --timeout 10m
    
    print_success "  ✓ Prometheus Operator installed successfully"
}

# Install LGTM Stack
install_lgtm_stack() {
    print_header "Installing LGTM Stack"
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local values_file="$script_dir/../helm/values-lgtm.local.yaml"
    
    local values_param=""
    if [ -f "$values_file" ]; then
        values_param="-f $values_file"
    else
        print_warning "  values-lgtm.local.yaml not found, using default values"
    fi
    
    print_info "Installing LGTM Stack (this may take several minutes)..."
    helm upgrade --install lgtm \
        grafana/lgtm-distributed \
        --version 2.1.0 \
        -n "$NAMESPACE" \
        $values_param \
        --wait \
        --timeout 15m
    
    print_success "  ✓ LGTM Stack installed successfully"
}

# Deploy additional components
deploy_additional_components() {
    print_header "Deploying Additional Components"
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local manifests_path="$script_dir/../manifests"
    
    # Deploy OpenTelemetry Collector
    if [ -f "$manifests_path/otel-collector.yaml" ]; then
        print_info "Deploying OpenTelemetry Collector..."
        kubectl apply -f "$manifests_path/otel-collector.yaml" -n "$NAMESPACE"
        print_success "  ✓ OpenTelemetry Collector deployed"
    fi
    
    # Deploy Promtail
    if [ -f "$manifests_path/promtail.docker.yaml" ]; then
        print_info "Deploying Promtail..."
        kubectl apply -f "$manifests_path/promtail.docker.yaml"
        print_success "  ✓ Promtail deployed"
    fi
    
    # Deploy .NET API application
    if [ -d "$manifests_path/src" ]; then
        print_info "Deploying .NET API application..."
        kubectl apply -f "$manifests_path/src" -n "$NAMESPACE"
        print_success "  ✓ .NET API application deployed"
    fi
}

# Main execution
main() {
    print_header "LGTM Stack Installation Script"
    print_info "Installing to namespace: $NAMESPACE"
    
    if [ "$SKIP_PREREQUISITES" = false ]; then
        check_prerequisites
    fi
    
    add_helm_repositories
    create_namespace
    install_prometheus_operator
    install_lgtm_stack
    deploy_additional_components
    
    print_header "Installation Complete!"
    
    print_success "The LGTM Stack has been successfully installed!"
    echo ""
    print_info "Next steps:"
    echo "  1. Get Grafana admin password:"
    echo "     kubectl get secret --namespace $NAMESPACE lgtm-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode"
    echo ""
    echo "  2. Access Grafana:"
    echo "     kubectl port-forward svc/lgtm-grafana 3000:80 -n $NAMESPACE"
    echo "     Open browser: http://localhost:3000"
    echo "     Username: admin"
    echo ""
    echo "  3. Test services:"
    echo "     ./test-services.sh"
}

# Run main function
main