---
description: Check Submariner health on ACM hub cluster
---

# Submariner ACM Hub Health Check

You are checking the health of Submariner-related resources on the ACM (Advanced Cluster Management) hub cluster.

## Your Role

This command analyzes Submariner resources managed by ACM on the hub cluster to identify configuration issues, deployment problems, or degraded states.

## Your Task

### Phase 1: Get Hub Kubeconfig

**Check if kubeconfig was provided as a parameter:**
- This command can be invoked as `/submariner:acm-hub-health <hub-kubeconfig>`
- If kubeconfig path is provided as parameter, use it directly
- If not provided, ask the user for it

Ask the user for (if not provided as parameters):
- Kubeconfig path for the ACM hub cluster

### Phase 2: Check ManagedClusterAddOn Resources

**Step 1: List all Submariner ManagedClusterAddOns**

```bash
kubectl get managedclusteraddon -A --kubeconfig <hub-kubeconfig> | grep submariner
```

This shows all managed clusters with Submariner addon installed.

**Step 2: Analyze Each ManagedClusterAddOn**

For each submariner managedclusteraddon found, get its full details:

```bash
kubectl get managedclusteraddon -n <namespace> submariner -o yaml --kubeconfig <hub-kubeconfig>
```

**Check the status.conditions[] array for issues:**

**HEALTHY Conditions (status: "True" is good):**
- `type: Configured` - status should be "True"
- `type: RegistrationApplied` - status should be "True"
- `type: SubmarinerBrokerConfigApplied` - status should be "True"
- `type: ManifestApplied` - status should be "True"
- `type: SubmarinerGatewayNodesLabeled` - status should be "True"
- `type: Available` - status should be "True"

**DEGRADED Conditions (status: "False" is good, "True" is bad):**
- `type: SubmarinerAgentDegraded` - status should be "False" (if "True", addon is degraded)
- `type: SubmarinerConnectionDegraded` - status should be "False" (if "True", connections are degraded)
- `type: RouteAgentConnectionDegraded` - status should be "False" (if "True", route agent connections are degraded)
- `type: Progressing` - status should be "False" when deployment is complete

**For each condition, check:**
- If condition type ends with "Degraded", status "True" = **PROBLEM**
- If condition type does NOT end with "Degraded", status "False" = **PROBLEM**
- Read the `message` and `reason` fields for details about any issues

### Phase 3: Check SubmarinerConfig Resources

**Step 1: List all SubmarinerConfig resources**

```bash
kubectl get submarinerconfig -A --kubeconfig <hub-kubeconfig>
```

This shows the configuration for each managed cluster.

**Step 2: Analyze Each SubmarinerConfig**

For each SubmarinerConfig, get its details:

```bash
kubectl get submarinerconfig -n <namespace> <name> -o yaml --kubeconfig <hub-kubeconfig>
```

**Check the status.conditions[] array:**

**Expected Healthy Conditions:**
- `type: SubmarinerConfigApplied` - status should be "True"
- `type: SubmarinerClusterEnvironmentPrepared` - status should be "True"
- `type: SubmarinerGatewaysLabeled` - status should be "True"

**For each condition:**
- Status "True" = healthy
- Status "False" = problem
- Check `message` and `reason` for error details

**Also verify:**
- `status.managedClusterInfo` contains cluster details (clusterName, platform, region, etc.)
- `spec.gatewayConfig.gateways` shows expected number of gateways
- Check for any error messages in the status

### Phase 4: Provide Health Summary

Create a comprehensive summary:

```
=== ACM HUB HEALTH CHECK SUMMARY ===

MANAGED CLUSTER ADDONS:
Cluster: <namespace>
  ✓ Configured: True
  ✓ Available: True
  ✓ ManifestApplied: True
  ✓ SubmarinerAgentDegraded: False (healthy)
  ✓ SubmarinerConnectionDegraded: False (healthy)
  ✓ RouteAgentConnectionDegraded: False (healthy)

Cluster: <namespace2>
  ⚠ SubmarinerAgentDegraded: True - PROBLEM DETECTED
     Message: <error message>
  ✓ Other conditions healthy

SUBMARINER CONFIGS:
Cluster: <namespace>
  ✓ SubmarinerConfigApplied: True
  ✓ SubmarinerClusterEnvironmentPrepared: True
  ✓ SubmarinerGatewaysLabeled: True
  ✓ Gateway nodes: <count> nodes labeled

Cluster: <namespace2>
  ⚠ SubmarinerGatewaysLabeled: False - PROBLEM DETECTED
     Message: <error message>
```

### Phase 5: Analyze Issues and Recommend Actions

Based on the findings, provide specific recommendations:

#### **ISSUE 1: SubmarinerAgentDegraded = True**

```
⚠ SUBMARINER AGENT DEGRADED on cluster: <cluster-name>

Message: <degraded message>

RECOMMENDED ACTIONS:
1. Check Submariner pod status on the managed cluster:
   kubectl get pods -n submariner-operator --kubeconfig <managed-cluster-kubeconfig>

2. Check Submariner operator logs:
   kubectl logs -n submariner-operator -l app=submariner-operator --kubeconfig <managed-cluster-kubeconfig>

3. Verify Submariner version and deployment status
```

#### **ISSUE 2: SubmarinerConnectionDegraded = True**

```
⚠ SUBMARINER CONNECTIONS DEGRADED on cluster: <cluster-name>

Message: <degraded message>

This means gateway-to-gateway connections are not established.

RECOMMENDED ACTIONS:
1. Run /submariner:troubleshoot-health on the managed cluster
2. Check tunnel status between clusters
3. Verify ESP/firewall configuration
```

#### **ISSUE 3: RouteAgentConnectionDegraded = True**

```
⚠ ROUTE AGENT CONNECTIONS DEGRADED on cluster: <cluster-name>

Message: <degraded message>

This means some nodes cannot reach remote gateways.

RECOMMENDED ACTIONS:
1. Check RouteAgent status on the managed cluster:
   kubectl get routeagents.submariner.io -n submariner-operator --kubeconfig <managed-cluster-kubeconfig>

2. Investigate local cluster routing issues on affected nodes
```

#### **ISSUE 4: SubmarinerConfigApplied = False**

```
⚠ SUBMARINER CONFIG NOT APPLIED on cluster: <cluster-name>

Message: <error message>

RECOMMENDED ACTIONS:
1. Check SubmarinerConfig resource for errors
2. Verify ACM managed cluster connection is healthy
3. Check addon controller logs on the hub
```

#### **ISSUE 5: SubmarinerGatewaysLabeled = False**

```
⚠ GATEWAY NODES NOT LABELED on cluster: <cluster-name>

Message: <error message>

RECOMMENDED ACTIONS:
1. Check if nodes exist in the cluster
2. Verify node selectors in gatewayConfig
3. Manually label gateway nodes if needed:
   kubectl label node <node-name> submariner.io/gateway=true --kubeconfig <managed-cluster-kubeconfig>
```

### Phase 6: Overall Health Status

End with a clear overall status:

```
=== OVERALL ACM HUB STATUS ===

Total Managed Clusters with Submariner: <count>
  ✓ Healthy: <count>
  ⚠ Degraded: <count>
  ✗ Failed: <count>

SubmarinerConfig Resources: <count>
  ✓ Applied Successfully: <count>
  ⚠ Issues: <count>

NEXT STEPS:
[If all healthy]
All Submariner resources on ACM hub are healthy!

[If issues found]
Address the issues listed above for each affected cluster.
Use /submariner:troubleshoot-health on managed clusters for detailed diagnostics.
```

## Important Guidelines

1. **Check BOTH resources** - ManagedClusterAddOn AND SubmarinerConfig
2. **Understand condition logic**:
   - "Degraded" conditions: False = good, True = bad
   - Other conditions: True = good, False = bad
3. **Read messages** - condition messages provide critical error details
4. **Per-cluster analysis** - report issues separately for each managed cluster
5. **Provide actionable steps** - tell users exactly how to fix each issue type

## What This Command Checks

✓ Submariner addon deployment status on managed clusters
✓ Gateway-to-gateway connection health
✓ RouteAgent connection health
✓ Gateway node labeling
✓ Configuration application status
✓ Cluster environment preparation

## What This Command Does NOT Check

✗ Actual connectivity between clusters (use /submariner:troubleshoot-health on managed cluster)
✗ Detailed pod status on managed clusters
✗ Network configuration on managed clusters
✗ Broker configuration (separate resource)

This command provides a high-level health overview from the ACM hub perspective!
