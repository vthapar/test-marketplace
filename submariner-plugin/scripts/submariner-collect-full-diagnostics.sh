#!/bin/bash
# Submariner Full Diagnostic Data Collector
# Uses subctl and kubectl to gather comprehensive troubleshooting data

# Don't use 'set -e' to avoid closing the shell on errors
# Instead, we'll handle errors explicitly

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_DIR="submariner-diagnostics-${TIMESTAMP}"
KUBECONFIG1="$1"
KUBECONFIG2="$2"
CONTEXT1="$3"
CONTEXT2="$4"
COMPLAINT="${5:-No specific complaint provided}"

show_usage() {
    echo "Usage: $0 <kubeconfig1> [kubeconfig2] [context1] [context2] [complaint-description]"
    echo ""
    echo "Arguments:"
    echo "  kubeconfig1          - Path to kubeconfig for cluster 1 (required)"
    echo "  kubeconfig2          - Path to kubeconfig for cluster 2 (optional, for multi-cluster diagnostics)"
    echo "  context1             - Context name for cluster 1 (optional, required for subctl verify)"
    echo "  context2             - Context name for cluster 2 (optional, required for subctl verify)"
    echo "  complaint-description - Description of the issue (optional)"
    echo ""
    echo "Examples:"
    echo "  # Single cluster diagnostics"
    echo "  $0 /path/to/kubeconfig1"
    echo ""
    echo "  # Multi-cluster diagnostics without verify"
    echo "  $0 /path/to/kubeconfig1 /path/to/kubeconfig2"
    echo ""
    echo "  # Multi-cluster diagnostics with verify (requires contexts)"
    echo "  $0 /path/to/kubeconfig1 /path/to/kubeconfig2 cluster1-context cluster2-context"
    echo ""
    echo "  # With complaint description"
    echo "  $0 /path/to/kubeconfig1 /path/to/kubeconfig2 cluster1 cluster2 'tunnel not connected'"
    return 1 2>/dev/null || exit 1
}

# Function to collect diagnostics from a single cluster
collect_cluster_diagnostics() {
    local cluster_name="$1"
    local kubeconfig="$2"
    local context="$3"
    local cluster_dir="${OUTPUT_DIR}/${cluster_name}"

    echo "=== Collecting from ${cluster_name} ==="
    mkdir -p "${cluster_dir}"

    # subctl gather (most comprehensive)
    echo "Running subctl gather for ${cluster_name}..."
    subctl gather --kubeconfig "${kubeconfig}" --dir "${cluster_dir}/gather" 2>&1 | tee "${cluster_dir}/gather.log"

    # subctl show (connection status)
    echo "Running subctl show for ${cluster_name}..."
    subctl show all --kubeconfig "${kubeconfig}" > "${cluster_dir}/subctl-show-all.txt" 2>&1

    # subctl diagnose (health checks)
    echo "Running subctl diagnose for ${cluster_name}..."
    subctl diagnose all --kubeconfig "${kubeconfig}" > "${cluster_dir}/subctl-diagnose-all.txt" 2>&1

    # Additional CRs that might not be in gather
    echo "Collecting additional CRs for ${cluster_name}..."
    kubectl get routeagents.submariner.io -n submariner-operator -o yaml --kubeconfig "${kubeconfig}" > "${cluster_dir}/routeagents.yaml" 2>&1 || echo "Failed to get RouteAgents" > "${cluster_dir}/routeagents.yaml"

    # ACM resources (if ACM hub or managed cluster)
    echo "Checking for ACM resources on ${cluster_name}..."
    kubectl get managedclusteraddon -A --kubeconfig "${kubeconfig}" 2>/dev/null | grep submariner > "${cluster_dir}/acm-addons.txt" || echo "No ACM ManagedClusterAddOn resources found" > "${cluster_dir}/acm-addons.txt"
    kubectl get submarinerconfig -A -o yaml --kubeconfig "${kubeconfig}" > "${cluster_dir}/submarinerconfig.yaml" 2>&1 || echo "No SubmarinerConfig resources found" > "${cluster_dir}/submarinerconfig.yaml"
}

if [ -z "$KUBECONFIG1" ]; then
    show_usage
fi

# Validate parameters before starting collection
echo "Validating parameters..."

# Validate kubeconfig1 exists
if [ ! -f "$KUBECONFIG1" ]; then
    echo "ERROR: Kubeconfig file not found: $KUBECONFIG1"
    return 1 2>/dev/null || exit 1
fi

# Validate kubeconfig1 is accessible
echo "Checking connectivity to cluster1..."
if ! kubectl cluster-info --kubeconfig "$KUBECONFIG1" &>/dev/null; then
    echo "ERROR: Cannot connect to cluster using kubeconfig: $KUBECONFIG1"
    echo "Please verify:"
    echo "  - The kubeconfig file is valid"
    echo "  - The cluster is accessible from this machine"
    echo "  - Your credentials are valid"
    return 1 2>/dev/null || exit 1
fi

# If context1 is provided, validate it exists in kubeconfig1
if [ -n "$CONTEXT1" ]; then
    if ! kubectl config get-contexts "$CONTEXT1" --kubeconfig "$KUBECONFIG1" &>/dev/null; then
        echo "ERROR: Context '$CONTEXT1' not found in kubeconfig: $KUBECONFIG1"
        echo "Available contexts:"
        kubectl config get-contexts --kubeconfig "$KUBECONFIG1" -o name
        return 1 2>/dev/null || exit 1
    fi
fi

# If kubeconfig2 is provided, validate it
if [ -n "$KUBECONFIG2" ]; then
    if [ ! -f "$KUBECONFIG2" ]; then
        echo "ERROR: Kubeconfig file not found: $KUBECONFIG2"
        return 1 2>/dev/null || exit 1
    fi

    echo "Checking connectivity to cluster2..."
    if ! kubectl cluster-info --kubeconfig "$KUBECONFIG2" &>/dev/null; then
        echo "ERROR: Cannot connect to cluster using kubeconfig: $KUBECONFIG2"
        echo "Please verify:"
        echo "  - The kubeconfig file is valid"
        echo "  - The cluster is accessible from this machine"
        echo "  - Your credentials are valid"
        return 1 2>/dev/null || exit 1
    fi

    # If both contexts are provided for verify, validate them
    if [ -n "$CONTEXT1" ] && [ -n "$CONTEXT2" ]; then
        # Validate context2 exists in kubeconfig2
        if ! kubectl config get-contexts "$CONTEXT2" --kubeconfig "$KUBECONFIG2" &>/dev/null; then
            echo "ERROR: Context '$CONTEXT2' not found in kubeconfig: $KUBECONFIG2"
            echo "Available contexts:"
            kubectl config get-contexts --kubeconfig "$KUBECONFIG2" -o name
            return 1 2>/dev/null || exit 1
        fi

        # Validate contexts have different names
        if [ "$CONTEXT1" = "$CONTEXT2" ]; then
            echo "ERROR: Context names must be different for cluster1 and cluster2"
            echo "  --context (cluster1): $CONTEXT1"
            echo "  --tocontext (cluster2): $CONTEXT2"
            echo ""
            echo "Using the same context for both clusters will cause 'subctl verify' to fail."
            echo "Please provide unique context names for each cluster."
            echo ""
            echo "Available contexts in kubeconfig1:"
            kubectl config get-contexts --kubeconfig "$KUBECONFIG1" -o name
            if [ "$KUBECONFIG1" != "$KUBECONFIG2" ]; then
                echo ""
                echo "Available contexts in kubeconfig2:"
                kubectl config get-contexts --kubeconfig "$KUBECONFIG2" -o name
            fi
            return 1 2>/dev/null || exit 1
        fi
    fi
fi

# Check for required tools
echo "Checking for required tools..."
if ! command -v subctl &>/dev/null; then
    echo "ERROR: 'subctl' command not found"
    echo "Please install subctl from: https://github.com/submariner-io/subctl"
    return 1 2>/dev/null || exit 1
fi

if ! command -v kubectl &>/dev/null; then
    echo "ERROR: 'kubectl' command not found"
    echo "Please install kubectl"
    return 1 2>/dev/null || exit 1
fi

echo "✓ All validations passed"
echo ""

mkdir -p "${OUTPUT_DIR}"

echo "Collecting Submariner diagnostics..."
echo "Timestamp: ${TIMESTAMP}" > "${OUTPUT_DIR}/manifest.txt"
echo "Complaint: ${COMPLAINT}" >> "${OUTPUT_DIR}/manifest.txt"
echo "" >> "${OUTPUT_DIR}/manifest.txt"

# Collect from Cluster 1
echo "Kubeconfig: ${KUBECONFIG1}" >> "${OUTPUT_DIR}/manifest.txt"
if [ -n "$CONTEXT1" ]; then
    echo "Context: ${CONTEXT1}" >> "${OUTPUT_DIR}/manifest.txt"
fi

collect_cluster_diagnostics "cluster1" "${KUBECONFIG1}" "${CONTEXT1}"

# Collect from Cluster 2 (if provided)
if [ -n "$KUBECONFIG2" ]; then
    echo "" >> "${OUTPUT_DIR}/manifest.txt"
    echo "Cluster 2:" >> "${OUTPUT_DIR}/manifest.txt"
    echo "Kubeconfig: ${KUBECONFIG2}" >> "${OUTPUT_DIR}/manifest.txt"
    if [ -n "$CONTEXT2" ]; then
        echo "Context: ${CONTEXT2}" >> "${OUTPUT_DIR}/manifest.txt"
    fi

    collect_cluster_diagnostics "cluster2" "${KUBECONFIG2}" "${CONTEXT2}"
fi

# Run connectivity verification (if both clusters and contexts provided)
if [ -n "$KUBECONFIG2" ] && [ -n "$CONTEXT1" ] && [ -n "$CONTEXT2" ]; then
    echo "=== Running connectivity verification ==="
    mkdir -p "${OUTPUT_DIR}/verify"

    # Detect which image registry is accessible by actually trying to create pods on BOTH clusters
    echo "Detecting accessible image registry for nettest..."
    IMAGE_OVERRIDE=""
    RH_REGISTRY_OK=true

    # Test default Red Hat registry on cluster1
    echo "Testing registry.redhat.io/rhacm2/nettest:0.21.0 on cluster1..."
    kubectl run nettest-registry-check --image=registry.redhat.io/rhacm2/nettest:0.21.0 --restart=Never --kubeconfig="${KUBECONFIG1}" --context="${CONTEXT1}" --command -- sleep 1 >/dev/null 2>&1
    sleep 3
    POD_STATUS=$(kubectl get pod nettest-registry-check --kubeconfig="${KUBECONFIG1}" --context="${CONTEXT1}" -o jsonpath='{.status.containerStatuses[0].state}' 2>/dev/null)

    if echo "$POD_STATUS" | grep -qE "running|terminated|waiting.*PodInitializing|waiting.*ContainerCreating"; then
        echo "  ✓ Cluster1: registry.redhat.io is accessible"
    else
        echo "  ✗ Cluster1: registry.redhat.io not accessible (ImagePullBackOff)"
        RH_REGISTRY_OK=false
    fi
    kubectl delete pod nettest-registry-check --kubeconfig="${KUBECONFIG1}" --context="${CONTEXT1}" --wait=false >/dev/null 2>&1

    # Test default Red Hat registry on cluster2
    echo "Testing registry.redhat.io/rhacm2/nettest:0.21.0 on cluster2..."
    kubectl run nettest-registry-check --image=registry.redhat.io/rhacm2/nettest:0.21.0 --restart=Never --kubeconfig="${KUBECONFIG2}" --context="${CONTEXT2}" --command -- sleep 1 >/dev/null 2>&1
    sleep 3
    POD_STATUS=$(kubectl get pod nettest-registry-check --kubeconfig="${KUBECONFIG2}" --context="${CONTEXT2}" -o jsonpath='{.status.containerStatuses[0].state}' 2>/dev/null)

    if echo "$POD_STATUS" | grep -qE "running|terminated|waiting.*PodInitializing|waiting.*ContainerCreating"; then
        echo "  ✓ Cluster2: registry.redhat.io is accessible"
    else
        echo "  ✗ Cluster2: registry.redhat.io not accessible (ImagePullBackOff)"
        RH_REGISTRY_OK=false
    fi
    kubectl delete pod nettest-registry-check --kubeconfig="${KUBECONFIG2}" --context="${CONTEXT2}" --wait=false >/dev/null 2>&1

    # If both clusters can access Red Hat registry, use default image
    if [ "$RH_REGISTRY_OK" = "true" ]; then
        echo "  ✓ Both clusters can access registry.redhat.io - using default image"
    else
        echo "  ✗ At least one cluster cannot access registry.redhat.io - using quay.io mirror"
        IMAGE_OVERRIDE="--image-override submariner-nettest=quay.io/submariner/nettest:devel"
    fi

    # Merge kubeconfigs temporarily for subctl verify
    MERGED_KUBECONFIG="${OUTPUT_DIR}/merged-kubeconfig"
    KUBECONFIG="${KUBECONFIG1}:${KUBECONFIG2}" kubectl config view --flatten > "${MERGED_KUBECONFIG}"

    echo "Running subctl verify for connectivity (default packet size)..."
    VERIFY_CMD="KUBECONFIG=${MERGED_KUBECONFIG} subctl verify --context ${CONTEXT1} --tocontext ${CONTEXT2} --only connectivity --verbose ${IMAGE_OVERRIDE}"
    echo "========================================" > "${OUTPUT_DIR}/verify/connectivity.txt"
    echo "Command executed:" >> "${OUTPUT_DIR}/verify/connectivity.txt"
    echo "${VERIFY_CMD}" >> "${OUTPUT_DIR}/verify/connectivity.txt"
    echo "========================================" >> "${OUTPUT_DIR}/verify/connectivity.txt"
    echo "" >> "${OUTPUT_DIR}/verify/connectivity.txt"
    KUBECONFIG="${MERGED_KUBECONFIG}" subctl verify --context "${CONTEXT1}" --tocontext "${CONTEXT2}" --only connectivity --verbose ${IMAGE_OVERRIDE} >> "${OUTPUT_DIR}/verify/connectivity.txt" 2>&1 || echo "Connectivity verification failed or timed out" >> "${OUTPUT_DIR}/verify/connectivity.txt"

    echo "Running subctl verify for connectivity (small packet size for MTU testing)..."
    VERIFY_CMD="KUBECONFIG=${MERGED_KUBECONFIG} subctl verify --context ${CONTEXT1} --tocontext ${CONTEXT2} --only connectivity --verbose --packet-size 400 ${IMAGE_OVERRIDE}"
    echo "========================================" > "${OUTPUT_DIR}/verify/connectivity-small-packet.txt"
    echo "Command executed:" >> "${OUTPUT_DIR}/verify/connectivity-small-packet.txt"
    echo "${VERIFY_CMD}" >> "${OUTPUT_DIR}/verify/connectivity-small-packet.txt"
    echo "========================================" >> "${OUTPUT_DIR}/verify/connectivity-small-packet.txt"
    echo "" >> "${OUTPUT_DIR}/verify/connectivity-small-packet.txt"
    KUBECONFIG="${MERGED_KUBECONFIG}" subctl verify --context "${CONTEXT1}" --tocontext "${CONTEXT2}" --only connectivity --verbose --packet-size 400 ${IMAGE_OVERRIDE} >> "${OUTPUT_DIR}/verify/connectivity-small-packet.txt" 2>&1 || echo "Connectivity verification with small packets failed or timed out" >> "${OUTPUT_DIR}/verify/connectivity-small-packet.txt"

    # Check if service discovery is enabled before running the test
    echo "Checking if service discovery is enabled..."
    SD_ENABLED_CLUSTER1=$(kubectl get submariner submariner -n submariner-operator --kubeconfig "${KUBECONFIG1}" -o jsonpath='{.spec.serviceDiscoveryEnabled}' 2>/dev/null)
    SD_ENABLED_CLUSTER2=$(kubectl get submariner submariner -n submariner-operator --kubeconfig "${KUBECONFIG2}" -o jsonpath='{.spec.serviceDiscoveryEnabled}' 2>/dev/null)

    if [ "$SD_ENABLED_CLUSTER1" = "true" ] || [ "$SD_ENABLED_CLUSTER2" = "true" ]; then
        echo "Running subctl verify for service-discovery..."
        VERIFY_CMD="KUBECONFIG=${MERGED_KUBECONFIG} subctl verify --context ${CONTEXT1} --tocontext ${CONTEXT2} --only service-discovery --verbose ${IMAGE_OVERRIDE}"
        echo "========================================" > "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "Command executed:" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "${VERIFY_CMD}" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "========================================" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        KUBECONFIG="${MERGED_KUBECONFIG}" subctl verify --context "${CONTEXT1}" --tocontext "${CONTEXT2}" --only service-discovery --verbose ${IMAGE_OVERRIDE} >> "${OUTPUT_DIR}/verify/service-discovery.txt" 2>&1 || echo "Service discovery verification failed or timed out" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
    else
        echo "Skipping service-discovery verification (not enabled on either cluster)"
        echo "========================================" > "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "SERVICE DISCOVERY VERIFICATION SKIPPED" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "========================================" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "Service discovery is not enabled on either cluster." >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "Cluster1 serviceDiscoveryEnabled: ${SD_ENABLED_CLUSTER1:-not set (defaults to false)}" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "Cluster2 serviceDiscoveryEnabled: ${SD_ENABLED_CLUSTER2:-not set (defaults to false)}" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
        echo "To enable service discovery, see: https://submariner.io/getting-started/quickstart/openshift/service-discovery/" >> "${OUTPUT_DIR}/verify/service-discovery.txt"
    fi

    # Cleanup merged kubeconfig
    rm -f "${MERGED_KUBECONFIG}"
else
    if [ -n "$KUBECONFIG2" ]; then
        echo "=== Skipping connectivity verification ==="
        echo "Note: To include subctl verify tests, provide context names for both clusters" > "${OUTPUT_DIR}/verify-skipped.txt"
        echo "Usage: $0 <kubeconfig1> <kubeconfig2> <context1> <context2> [complaint]" >> "${OUTPUT_DIR}/verify-skipped.txt"
    fi
fi

# Create tarball
echo ""
echo "Creating tarball..."
tar -czf "${OUTPUT_DIR}.tar.gz" "${OUTPUT_DIR}"

# Cleanup directory (keep only tarball)
rm -rf "${OUTPUT_DIR}"

echo ""
echo "=========================================="
echo "Diagnostic collection complete!"
echo "Output: ${OUTPUT_DIR}.tar.gz"
echo "=========================================="
echo ""
echo "Contents:"
if [ -n "$KUBECONFIG2" ]; then
    echo "  - Cluster 1 diagnostics (subctl gather, show, diagnose)"
    echo "  - Cluster 2 diagnostics (subctl gather, show, diagnose)"
    if [ -n "$CONTEXT1" ] && [ -n "$CONTEXT2" ]; then
        echo "  - Connectivity verification results"
        echo "  - Service discovery verification results"
        echo "  - MTU testing (small packet size)"
    fi
else
    echo "  - Cluster 1 diagnostics (subctl gather, show, diagnose)"
fi
echo "  - RouteAgent status"
echo "  - ACM resources (if present)"
echo ""
echo "Next steps:"
echo "1. Share this tarball with your support team or Submariner expert"
echo "2. They can analyze it offline without needing cluster access"
echo "3. For AI-assisted analysis with Claude Code, run:"
echo "   /submariner:analyze-offline ${OUTPUT_DIR}.tar.gz"
echo ""
