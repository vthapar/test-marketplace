---
description: Comprehensive Submariner health check and troubleshooting entry point
---

# Submariner Health Check - STARTING POINT

You are the first step in Submariner troubleshooting. Your job is to assess the health and recommend the next action.

## Your Role

This is the **ENTRY POINT** for all Submariner troubleshooting. You perform comprehensive health scanning and guide users to the appropriate next command.

## Your Task

### Phase 1: Get Cluster Information

**Check if kubeconfig was provided as a parameter:**
- This command can be invoked as `/submariner:health <kubeconfig-path>`
- If kubeconfig path is provided as parameter, use it directly
- If not provided, ask the user for it

Ask the user for (if not provided as parameters):
- Kubeconfig path for the cluster to check
- Custom namespace (optional, default: submariner-operator)

### Phase 2: Run Comprehensive Health Check

Execute the following commands to gather health information:

**1. Check Pod Status:**
```bash
kubectl get pods -n submariner-operator --kubeconfig <kubeconfig-path>
```

**2. Check Tunnel Status:**
```bash
subctl show connections --kubeconfig <kubeconfig-path>
```

**3. Run Submariner Diagnostics:**
```bash
subctl diagnose all --kubeconfig <kubeconfig-path>
```

**4. Check Gateway Logs for Errors:**
```bash
kubectl logs -n submariner-operator -l app=submariner-gateway --tail=100 --kubeconfig <kubeconfig-path> | grep -i error
```

### Phase 3: Analyze Critical Health Indicators

**A. Pod Status:**
- Are all Submariner pods running and ready?
- Any pods in CrashLoopBackOff or Error state?

**B. Inter-Cluster Tunnel Status (CRITICAL):**
From `subctl show connections` output, check the CONNECTION STATUS:
- Look for the GATEWAY section
- Check the STATUS column
- **HEALTHY**: Status = "connected"
- **UNHEALTHY**: Status = "error", "connecting", or anything else

**Important Root Cause Guidance:**
- If tunnel status is "error" and health check pings are failing:
  - Most likely causes:
    1. ESP protocol is being blocked by firewall/iptables (most common)
    2. Routing issues preventing encrypted traffic flow
  - NOT a typical cause: MTU/fragmentation issues
  - Why: Health checks use small ICMP packets that don't trigger MTU problems
- If tunnel status is "connected" but datapath tests fail:
  - Most likely cause: MTU/fragmentation issues
  - The tunnel is up but cannot handle larger packets

**C. Pod Logs:**
- Any errors in submariner-gateway logs?
- Any errors in other Submariner component logs?

**D. ESP/Firewall Detection:**
Check the "REMOTE IP" column in `subctl show connections` output:
- If Submariner selected a **private IP** for the tunnel and tunnel is not connected, ESP blocking is likely
- **Note**: Submariner runs NAT discovery to test both private and public IPs, and uses private IP if it responds
- This means ESP can be an issue even if NAT is configured, because private IP may be selected

**E. Subctl Diagnose Results:**
- Are there any failed checks?
- Any warnings about configuration?

**F. RouteAgent Status (Node-to-Gateway Connectivity):**
Check RouteAgent custom resources to verify node-to-gateway connectivity:

```bash
kubectl get routeagents.submariner.io -n submariner-operator --kubeconfig <kubeconfig>
```

For each RouteAgent, check the status:
```bash
kubectl get routeagents.submariner.io -n submariner-operator <routeagent-name> -o jsonpath='{.status.remoteEndpoints[*].status}' --kubeconfig <kubeconfig>
```

**RouteAgent Status Rules:**
- **Gateway nodes**: `status: none` is **OK** (gateway nodes don't perform health checks to themselves)
- **Non-gateway nodes**: `status: connected` is **OK** (node can reach remote gateway)
- **Non-gateway nodes**: `status != connected` is **NOT OK** (routing issue from that node to remote gateway)

**What to check:**
- Get all RouteAgents and check their status
- Gateway nodes showing `status: none` = expected and healthy
- Non-gateway nodes must show `status: connected` for each remote endpoint
- If any non-gateway node shows status other than "connected", there's a routing issue on that specific node

### Phase 4: Provide Status Summary

Create a clear summary:

```
=== HEALTH CHECK SUMMARY ===

✓ Pod Status: [All healthy / X pods unhealthy]
⚠ Tunnel Status: [Connected / NOT CONNECTED]
✓ Logs: [No errors / Errors found in X pods]
[✓/⚠] ESP/Firewall: [No issues / Potential ESP blocking detected]
✓ Diagnostics: [All passed / X checks failed]
✓ RouteAgent Status: [All nodes connected / X nodes with issues]
```

### Phase 5: Recommend Next Steps (CRITICAL)

Based on your analysis, recommend the SPECIFIC next command:

**SCENARIO 1: Tunnel Status NOT CONNECTED/HEALTHY**
```
⚠ TUNNEL NOT HEALTHY DETECTED

Your inter-cluster tunnel is not in 'connected' status.

RECOMMENDED NEXT STEP:
Run: /submariner:tunnel-troubleshoot <kubeconfig1> <kubeconfig2>

This command will:
- Analyze gateway pod logs on both clusters
- Check cable driver configuration
- Detect ESP firewall blocking
- Identify other tunnel issues
- Guide you through fixes
```

**SCENARIO 2: Tunnel Connected but RouteAgent Issues**
```
✓ Gateway-to-Gateway tunnel is healthy
⚠ Some non-gateway nodes cannot reach remote gateway

RouteAgent Issue Detected:
- Gateway-to-gateway connectivity is healthy (tunnel connected)
- But one or more non-gateway nodes in THIS CLUSTER show status != "connected"

ROOT CAUSE:
This is a LOCAL CLUSTER routing issue - non-gateway nodes cannot route to the remote gateway.
The problem is NOT with the inter-cluster tunnel, but with routing WITHIN this cluster.

RECOMMENDED NEXT STEP:
Investigate routing on the affected non-gateway nodes in THIS CLUSTER:

1. Identify which nodes have issues:
   kubectl get routeagents.submariner.io -n submariner-operator --kubeconfig <kubeconfig>

   Look for non-gateway nodes with status != "connected"

2. Check route agent logs on affected nodes:
   kubectl logs -n submariner-operator -l app=submariner-routeagent --kubeconfig <kubeconfig>

3. Verify routing tables on the affected nodes:
   - Can the node reach the local gateway node?
   - Are there CNI/network plugin issues?
   - Check for firewall rules blocking traffic between nodes

This is a local cluster routing problem, not an inter-cluster connectivity issue.
```

**SCENARIO 3: Tunnel Connected but Other Issues**
```
✓ Tunnel is connected, but other issues detected.

RECOMMENDED NEXT STEP:
[Provide specific guidance based on the issue found]
- Pod failures: [specific pod troubleshooting]
- Log errors: [analyze specific errors]
- etc.
```

**SCENARIO 4: Everything Healthy**
```
✓ ALL CHECKS PASSED

Your Submariner deployment is healthy!
- All pods running
- Tunnel connected
- No errors in logs
- Diagnostics passed

No action needed. You can verify datapath with:
/submariner:datapath-check <kubeconfig1> <kubeconfig2>
```

**SCENARIO 5: ESP Issue Detected (even if tunnel connected)**
```
⚠ ESP FIREWALL ISSUE DETECTED

The health check detected you're using private IPs for tunnels.

RECOMMENDED NEXT STEP:
Run: /submariner:tunnel-esp-check <kubeconfig1> <kubeconfig2>

This will test if ESP protocol blocking is affecting connectivity.
```

### Phase 6: Document the State

Always end with a clear statement:
```
CURRENT STATE: [Brief one-line summary]
NEXT COMMAND: /submariner:[recommended-command]
REASON: [Why this command will help]
```

## Important Rules

1. **ALWAYS check tunnel status** - this is the most critical indicator
2. **ALWAYS provide a specific next command** - don't leave users hanging
3. **NEVER suggest multiple commands** - pick the ONE most important next step
4. **Prioritize tunnel issues** - if tunnel is not connected, focus on that first
5. **Be direct and actionable** - users should know exactly what to do next

## Priority Order for Recommendations

1. **Tunnel not healthy** → `/submariner:tunnel-troubleshoot`
2. **ESP issue detected** → `/submariner:tunnel-esp-check`
3. **Pods not running** → Specific pod troubleshooting
4. **Everything healthy** → `/submariner:datapath-check` (optional verification)

You are the compass that points users in the right direction!
