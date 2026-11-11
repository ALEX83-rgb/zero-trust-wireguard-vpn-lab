#!/bin/bash
# Generates WireGuard keys and gateway configs for both sites
set -e
mkdir -p gw_a gw_b
keys=$(docker run --rm alpine sh -c 'apk add -q wireguard-tools >/dev/null 2>&1; for i in 1 2; do k=$(wg genkey); echo "$k $(echo $k | wg pubkey)"; done')
A_PRIV=$(echo "$keys" | sed -n 1p | cut -d' ' -f1)
A_PUB=$(echo "$keys"  | sed -n 1p | cut -d' ' -f2)
B_PRIV=$(echo "$keys" | sed -n 2p | cut -d' ' -f1)
B_PUB=$(echo "$keys"  | sed -n 2p | cut -d' ' -f2)

cat > gw_a/wg0.conf <<EOF
[Interface]
Address = 10.10.10.1/24
PrivateKey = $A_PRIV
ListenPort = 51820

[Peer]
PublicKey = $B_PUB
Endpoint = 172.28.0.3:51820
AllowedIPs = 10.10.10.2/32, 172.28.2.0/24
EOF

cat > gw_b/wg0.conf <<EOF
[Interface]
Address = 10.10.10.2/24
PrivateKey = $B_PRIV
ListenPort = 51820

[Peer]
PublicKey = $A_PUB
Endpoint = 172.28.0.2:51820
AllowedIPs = 10.10.10.1/32, 172.28.1.0/24
EOF
echo "Configs generated in gw_a/ and gw_b/"
