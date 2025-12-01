#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
IFACE_BASE="enp0s3"
PHYSICAL_IP="192.168.160.2/24"

VLAN1_ID=170
VLAN2_ID=180

NS170="ns170"
NS180="ns180"

VLAN1_IP="192.168.170.2/24"
VLAN2_IP="192.168.180.2/24"

MCAST_ADDR_BASE="224.244.224.244/32"
MCAST_ADDR_170="224.244.224.245/32"
MCAST_ADDR_180="224.244.224.246/32"
# ---


echo "[+] Configuring provider network interfaces."
sudo -v

# ------------------------------
# Physical interface
# ------------------------------
echo "[*] Configuring physical interface ${IFACE_BASE}"
if ! ip addr show ${IFACE_BASE} | grep -q "${PHYSICAL_IP%/*}"; then
  sudo ip addr add ${PHYSICAL_IP} dev ${IFACE_BASE} 2>/dev/null || echo "[*] IP already exists on ${IFACE_BASE}"
fi
sudo ip link set ${IFACE_BASE} up

# ------------------------------
# Create network namespaces
# ------------------------------
echo "[*] Creating namespaces..."
sudo ip netns add ${NS170} 2>/dev/null || true
sudo ip netns add ${NS180} 2>/dev/null || true

# ------------------------------
# Create VLAN interfaces in root ns
# ------------------------------
create_vlan() {
  local vlan_id=$1
  local iface="${IFACE_BASE}.${vlan_id}"

  if ! ip link show "$iface" &>/dev/null; then
    echo "[*] Creating $iface"
    sudo ip link add link ${IFACE_BASE} name ${iface} type vlan id ${vlan_id}
  fi
  sudo ip link set ${iface} down
}

create_vlan $VLAN1_ID
create_vlan $VLAN2_ID

# ------------------------------
# Move VLANs into namespaces
# ------------------------------
echo "[*] Moving VLAN interfaces to namespaces..."

sudo ip link set ${IFACE_BASE}.${VLAN1_ID} netns ${NS170}
sudo ip link set ${IFACE_BASE}.${VLAN2_ID} netns ${NS180}

# ------------------------------
# Configure VLAN interfaces inside namespaces
# ------------------------------
echo "[*] Configuring VLAN IP addresses in namespaces..."

sudo ip netns exec ${NS170} ip addr add ${VLAN1_IP} dev ${IFACE_BASE}.${VLAN1_ID}
sudo ip netns exec ${NS170} ip link set ${IFACE_BASE}.${VLAN1_ID} up
sudo ip netns exec ${NS170} ip link set lo up

sudo ip netns exec ${NS180} ip addr add ${VLAN2_IP} dev ${IFACE_BASE}.${VLAN2_ID}
sudo ip netns exec ${NS180} ip link set ${IFACE_BASE}.${VLAN2_ID} up
sudo ip netns exec ${NS180} ip link set lo up

# ------------------------------
# Multicast routes
# ------------------------------
echo "[*] Adding multicast routes..."

# Base multicast stays in root namespace
sudo ip route add ${MCAST_ADDR_BASE} dev ${IFACE_BASE} 2>/dev/null || true

# Per-VLAN multicast in their namespaces
sudo ip netns exec ${NS170} ip route add ${MCAST_ADDR_170} dev ${IFACE_BASE}.${VLAN1_ID} 2>/dev/null || true
sudo ip netns exec ${NS180} ip route add ${MCAST_ADDR_180} dev ${IFACE_BASE}.${VLAN2_ID} 2>/dev/null || true

echo "[+] Provider network ready!"
echo ""

# ------------------------------
# --- . Verification ---
# ------------------------------
echo "Verifying network configuration in each network namespace:"
echo "=== Root namespace interfaces ==="
ip -br addr show ${IFACE_BASE}
echo ""

echo "=== Namespace ${NS170} ==="
sudo ip netns exec ${NS170} ip -br addr
sudo ip netns exec ${NS170} ip route
echo ""

echo "=== Namespace ${NS180} ==="
sudo ip netns exec ${NS180} ip -br addr
sudo ip netns exec ${NS180} ip route
echo ""
