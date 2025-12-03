---
description: Troubleshoot why Submariner tunnels are not connected
---

# Submariner Tunnel Troubleshooting

You are helping troubleshoot why Submariner inter-cluster tunnels are not in 'connected' status.

## Your Role

The `/submariner:troubleshoot-health` command detected that the tunnel is NOT healthy. Your job is to:
1. Investigate WHY the tunnel is not connected
2. Identify the root cause
3. Guide the user to the appropriate fix command

## Your Task

### Phase 1: Gather Information

**This command troubleshoots the tunnel between TWO clusters.**

**Check if kubeconfigs were provided as parameters:**
- This command can be invoked as `/submariner:troubleshoot-tunnel <kubeconfig1> <kubeconfig2>`
- If both kubeconfig paths are provided as parameters, use them directly
- If not provided, ask the user for them

**Important for multi-cluster mesh scenarios:**
- Submariner creates full-mesh tunnels (e.g., 3 clusters = ClusterA↔ClusterB, ClusterA↔ClusterC, ClusterB↔ClusterC)
- This command analyzes **ONE tunnel at a time** between two specific clusters
- If you have 3 clusters and multiple tunnels are failing, run this command separately for each failing tunnel

Ask the user for (if not provided as parameters):
- Kubeconfig path for **cluster 1** (one side of the tunnel)
- Kubeconfig path for **cluster 2** (other side of the tunnel)
- Submariner namespace (optional, default: submariner-operator)

### Phase 2: Analyze Gateway Logs on Both Clusters

**For both clusters, check the submariner-gateway pod logs:**

**Cluster 1 Gateway Logs:**
```bash
kubectl logs -n submariner-operator -l app=submariner-gateway --tail=100 --kubeconfig <kubeconfig1>
```

**Cluster 2 Gateway Logs:**
```bash
kubectl logs -n submariner-operator -l app=submariner-gateway --tail=100 --kubeconfig <kubeconfig2>
```

**Analyze logs on BOTH sides of the tunnel.**

**Look for common error patterns:**
- `"ESP"` or `"protocol 50"` → ESP firewall blocking
- `"timeout"` → Network connectivity or firewall issues
- `"authentication failed"` → IPSec PSK mismatch or certificate issues
- `"no route"` → Routing configuration problems
- `"connection refused"` → Gateway port blocked (UDP 500, 4500, or ESP)
- `"no suitable proposal"` → IPSec proposal mismatch

### Phase 3: Check Gateway CR (Authoritative Source)

**CRITICAL: The Gateway CR is the authoritative source for tunnel configuration and status.**

**Get Gateway CR from both clusters:**
```bash
kubectl get gateway -n submariner-operator --kubeconfig <kubeconfig1> -o yaml
kubectl get gateway -n submariner-operator --kubeconfig <kubeconfig2> -o yaml
```

**Analyze the Gateway CR for each cluster under `status.connections[]`:**

**A. Cable Driver Type:**
- Check `status.connections[].endpoint.backend`
- Is it `libreswan` (IPSec) or `wireguard`?

**B. IP Address Selection (CRITICAL):**
- Check `status.connections[].usingIP` - this is the IP actually being used for the tunnel
- Compare with `status.connections[].endpoint.private_ip`
- Compare with `status.connections[].endpoint.public_ip`
- **If `usingIP == private_ip`** → Submariner selected private IP for tunnel
- **If `usingIP == public_ip`** → Submariner selected public IP for tunnel

**C. NAT Status:**
- Check `status.connections[].endpoint.nat_enabled`
- `true` or `false`

**D. Connection Status:**
- Check `status.connections[].status`
- Is it "connected", "error", "connecting", or something else?
- Check `status.connections[].statusMessage` for error details

**E. Protocol Selection Logic:**
- **IMPORTANT**: When `usingIP == private_ip` with `libreswan` → ESP protocol (IP protocol 50) is used
- **IMPORTANT**: When `usingIP == public_ip` with `libreswan` → UDP encapsulation (port 4500) is used
- **NAT Discovery**: Submariner tests both private and public IPs during NAT discovery
- If private IP responds, Submariner will select it even if `nat_enabled: true`

### Phase 4: Optional - Check subctl show connections

**For additional context, you can run:**
```bash
subctl show connections --kubeconfig <kubeconfig1>
```

This provides a quick summary view but is less detailed than the Gateway CR.

### Phase 5: Diagnose Root Cause

Based on your findings, identify the issue:

#### **DIAGNOSIS 1: ESP Firewall Blocking**

**Detection Criteria (Check Gateway CR):**
- `status.connections[].endpoint.backend == "libreswan"` (IPSec)
- `status.connections[].usingIP == status.connections[].endpoint.private_ip` (using private IP)
- `status.connections[].status == "error"` (tunnel not connected)
- `status.connections[].statusMessage` contains ping failure or health check failure

**Additional Indicators from Logs:**
- Gateway logs may show ESP or protocol 50 errors (but not always)
- Logs may show continuous NAT discovery attempts
- Initial connection may have succeeded, then failed later (indicates network change)
- OR connection never succeeded (indicates persistent ESP blocking)

**Root Cause (Most Likely):**
When `usingIP == private_ip` with `libreswan`, IPSec uses **ESP protocol (IP protocol 50)** for data encapsulation.
If ESP is blocked by firewall/iptables rules between the gateway nodes, the tunnel cannot pass traffic even though:
- NAT discovery succeeds (uses UDP)
- IKE negotiation succeeds (uses UDP 500/4500)
- IPSec SAs are established
- But actual data packets (health checks, pod traffic) fail

**Important Notes:**
- This can happen even with `nat_enabled: true` because NAT discovery tests both IPs and selects private if it responds
- ESP blocking can be introduced after tunnels are working (firewall rule changes, network updates)
- The IPsec control plane (IKE) works fine because it uses UDP, but the data plane (ESP) is blocked

**Recommendation:**
```
⚠ ESP FIREWALL BLOCKING DETECTED

Root Cause: ESP protocol (IP 50) is likely blocked in your firewall.

Detection: Gateway CR shows usingIP matches private_ip with libreswan backend and error status.

NEXT STEP: Run /submariner:troubleshoot-esp-check

This command will:
- Apply forceUDPEncaps to both clusters
- Force IPSec to use UDP port 4500 instead of ESP
- Restart gateway pods
- Verify if tunnel comes up
```

#### **DIAGNOSIS 2: Port Blocking (UDP 500, 4500)**

**Detection Criteria (Check Gateway CR):**
- `status.connections[].usingIP == status.connections[].endpoint.public_ip` (using public IP)
- OR `status.connections[].endpoint.backend == "wireguard"`
- `status.connections[].status == "error"` or "connecting"
- Gateway logs show "timeout" or "connection refused"

**Additional Indicators:**
- No ESP-related errors in logs
- IKE negotiation may be failing

**Root Cause (Most Likely):**
Required UDP ports could be blocked in firewall.

**Recommendation:**
```
⚠ UDP PORT BLOCKING DETECTED

Root Cause: UDP ports 500 or 4500 are likely blocked.

NEXT STEP: Check firewall rules

For IPSec, ensure these ports are open:
- UDP 500 (IKE)
- UDP 4500 (NAT-T / IPSec over UDP)

For WireGuard, ensure:
- UDP 4500 (WireGuard)

After opening ports, restart gateway pods:
kubectl delete pods -n submariner-operator -l app=submariner-gateway --kubeconfig <kubeconfig>
```

#### **DIAGNOSIS 3: IPSec Authentication/Proposal Issues**

**Indicators:**
- Logs show "authentication failed" or "no suitable proposal"
- PSK or certificate mismatches

**Root Cause (Most Likely):**
IPSec configuration could have a mismatch between clusters.

**Recommendation:**
```
⚠ IPSEC CONFIGURATION MISMATCH

Root Cause (Most Likely): IPSec authentication or proposal settings may not match.

NEXT STEP: Verify Broker configuration

1. Check that both clusters are using the same broker
2. Verify IPSec PSK secret matches:
   kubectl get secret -n submariner-operator ipsec-psk -o yaml --kubeconfig <kubeconfig>

3. Check Submariner operator logs for more details
```

#### **DIAGNOSIS 4: Network Connectivity Issues**

**Indicators:**
- Logs show timeouts or unreachable errors
- No specific ESP or port blocking errors
- Basic network connectivity may be broken

**Root Cause (Most Likely):**
Gateway nodes may not be able to reach each other at the network layer.

**Recommendation:**
```
⚠ NETWORK CONNECTIVITY ISSUE

Root Cause (Most Likely): Gateway nodes may not be able to communicate.

NEXT STEP: Verify basic network connectivity

1. Get gateway node IPs from both clusters:
   kubectl get nodes -l submariner.io/gateway=true -o wide --kubeconfig <kubeconfig>

2. Test connectivity manually:
   - From cluster1 gateway node, ping cluster2 gateway IP
   - Check routing tables
   - Verify no intermediate firewalls blocking traffic

3. Check route agent logs:
   kubectl logs -n submariner-operator -l app=submariner-routeagent --kubeconfig <kubeconfig>
```

#### **DIAGNOSIS 5: Other Issues**

If none of the above patterns match, provide a detailed analysis of the logs and suggest manual investigation steps.

### Phase 6: Provide Clear Action Plan

**Always end with:**

```
=== TUNNEL TROUBLESHOOTING SUMMARY ===

FINDING: [What you discovered]
ROOT CAUSE (Most Likely): [Why the tunnel is not connected - use cautious language]
NEXT COMMAND: /submariner:[specific-command]
EXPECTED OUTCOME: [What should happen after running the command]

If the issue persists after running the recommended command, re-run:
/submariner:troubleshoot-health <kubeconfig>

to reassess the situation.
```

## Important Guidelines

1. **ALWAYS check Gateway CR first** - it is the authoritative source for tunnel configuration and status
2. **Use Gateway CR for ESP detection** - check if `usingIP == private_ip` with `backend: libreswan` and `status: error`
3. **Gateway logs provide context** - but may not always show explicit "ESP" errors even when ESP is blocked
4. **Check BOTH clusters** - the issue might be on either side, verify Gateway CR on both
5. **Recognize failure patterns**:
   - **Immediate failure** (never connected): Persistent firewall/ESP blocking
   - **Delayed failure** (worked then failed): Network/firewall changes introduced later
6. **Prioritize ESP issues** - this is the most common problem (80% of cases)
7. **Provide ONE clear next step** - don't overwhelm the user with multiple options
8. **Be specific** - tell them exactly what command to run next

## Priority Order for Diagnosis

1. **ESP blocking** (most common) → `/submariner:troubleshoot-esp-check`
2. **UDP port blocking** → Firewall configuration
3. **IPSec auth/proposal** → Broker verification
4. **Network connectivity** → Manual network troubleshooting

You are the detective that finds the root cause!
