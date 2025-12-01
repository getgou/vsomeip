#!/bin/bash
set -e

# IMPORTANT: run this entire script with sudo
if [[ $EUID -ne 0 ]]; then
    echo "Please run with sudo:"
    echo "    sudo $0"
    exit 1
fi

NS170="ns170"
NS180="ns180"

PROJ_VSOMEIP_BUILD_DIR="/home/get/repo/vsomeip/build"
PROJ_DIR="/home/get/repo/vsomeip/vsomeip_goitom/Apps/multi-vlan-apps"
BUILD_DIR="${PROJ_DIR}/build"
CONFIG_DIR="${PROJ_DIR}/config"

ROUTER_CFG170="${CONFIG_DIR}/vsomeip-udp-service-router-vlan170.json"
ROUTER_CFG180="${CONFIG_DIR}/vsomeip-udp-service-router-vlan180.json"
CFG170="${CONFIG_DIR}/vsomeip-udp-service-vlan170.json"
CFG180="${CONFIG_DIR}/vsomeip-udp-service-vlan180.json"

ROUTING_BIN="${BUILD_DIR}/RoutingManagerService"

echo "Using config for VLAN170: $CFG170"
echo "Using config for VLAN180: $CFG180"
echo "Binary directory: $BUILD_DIR"
echo


# Check namespaces exist
for ns in "$NS170" "$NS180"; do
    if ! ip netns list | grep -q "^${ns}\b"; then
        echo "ERROR: Netns '${ns}' does not exist."
        exit 1
    fi
done

echo "Starting RoutingManagerService in ${NS170}..."

ROUTING_PID_170=$(ip netns exec ${NS170} bash -c "
    export LD_LIBRARY_PATH='${PROJ_VSOMEIP_BUILD_DIR}';
    export VSOMEIP_CONFIGURATION='${ROUTER_CFG170}';
    '${ROUTING_BIN}' >  /tmp/ns170_routing.log 2>&1 &
    echo \$!
")
echo " → RoutingManagerService PID (ns170) = ${ROUTING_PID_170}"
sleep 1

echo "Starting ServiceProviderApp (170) in ${NS170}..."

VLAN170_PID=$(ip netns exec ${NS170} bash -c "
    export LD_LIBRARY_PATH='${PROJ_VSOMEIP_BUILD_DIR}';
    export VSOMEIP_CONFIGURATION_SRVGW170='${CFG170}';
    '${BUILD_DIR}/response-sample-170' > /tmp/ns170.log 2>&1 &
    echo \$!
")

echo " → PID inside ns170: $VLAN170_PID"
sleep 2

echo "Starting RoutingManagerService in ${NS180}..."

ROUTING_PID_180=$(ip netns exec ${NS180} bash -c "
    export LD_LIBRARY_PATH='${PROJ_VSOMEIP_BUILD_DIR}';
    export VSOMEIP_CONFIGURATION='${ROUTER_CFG180}';
    '${ROUTING_BIN}' >  /tmp/ns180_routing.log 2>&1 &
    echo \$!
")

echo " → RoutingManagerService PID (ns180) = ${ROUTING_PID_180}"
sleep 1

echo "Starting ServiceProviderApp (180) in ${NS180}..."

VLAN180_PID=$(ip netns exec ${NS180} bash -c "
    export LD_LIBRARY_PATH='${PROJ_VSOMEIP_BUILD_DIR}';
    export VSOMEIP_CONFIGURATION_SRVGW180='${CFG180}';
    '${BUILD_DIR}/response-sample-180' > /tmp/ns180.log 2>&1 &
    echo \$!
")

echo " → PID inside ns180: $VLAN180_PID"
sleep 2

echo
echo "All processes running!"
echo "ns170 PID = $VLAN170_PID"
echo "ns170 router PID:   $ROUTING_PID_170"
echo "ns180 PID = $VLAN180_PID"
echo "ns180 router PID:   $ROUTING_PID_180"

echo
echo "===== VSOMEIP LIVE LOGS (Ctrl+C to exit log view) ====="
tail -n +1 -F \
    /tmp/ns170_routing.log \
    /tmp/ns170.log \
    /tmp/ns180_routing.log \
    /tmp/ns180.log    
