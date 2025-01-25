#!/bin/bash

# Create bond4 configuration
cat > /etc/sysconfig/network-scripts/ifcfg-bond4 << EOF
DEVICE=bond4
TYPE=Bond
BONDING_MASTER=yes
BOOTPROTO=none
ONBOOT=yes
BONDING_OPTS="mode=4 miimon=100"
EOF

# Configure lan0
cat > /etc/sysconfig/network-scripts/ifcfg-lan0 << EOF
DEVICE=lan0
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
MASTER=bond4
SLAVE=yes
EOF

# Configure lan1
cat > /etc/sysconfig/network-scripts/ifcfg-lan1 << EOF
DEVICE=lan1
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
MASTER=bond4
SLAVE=yes
EOF

# Restart network service
systemctl restart network 