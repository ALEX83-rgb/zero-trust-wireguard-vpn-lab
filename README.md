# Containerized Zero-Trust VPN Gateway & Traffic Inspection Lab

Two isolated Docker networks (Site A and Site B) connected through an encrypted WireGuard tunnel, with a default-deny iptables firewall and packet-capture verification of the encryption.

## Architecture

```
client_a ──► gateway A ══(WireGuard, UDP 51820)══► gateway B ──► client_b
172.28.1.10   172.28.1.254   transit 172.28.0.0/24   172.28.2.254   172.28.2.10
              (wg 10.10.10.1)                         (wg 10.10.10.2)
```

| Network | Subnet |
|---|---|
| site_a_net | 172.28.1.0/24 |
| site_b_net | 172.28.2.0/24 |
| transit (underlay) | 172.28.0.0/24 |

## Tools

Docker, Docker Compose, WireGuard, iptables (conntrack), tcpdump, Alpine Linux, Kali Linux (VMware).

## How to run

Requires a Linux host with kernel 5.6+ and Docker with the Compose plugin.

```bash
git clone <your-repo-url> && cd <repo-name>
bash setup.sh            # generates WireGuard keys and configs
docker compose up -d    # starts gateways and clients
sleep 30                # wait for packages to install
docker exec client-a ping -c 3 172.28.2.10
docker exec vpn-gateway-a wg show
bash firewall.sh         # applies zero-trust rules
docker compose down     # clean up
```

## Zero-trust firewall policy (gateway A)

- Default `FORWARD` policy: **DROP**
- Telnet (TCP 23) explicitly blocked
- Return traffic allowed via stateful inspection (`conntrack`)
- Only ICMP and TCP 22, 80, 443, 8080 allowed into the tunnel
- `AllowedIPs` restricts each peer to the remote site's subnet only

## Verification

Test Telnet and web listeners on Site B, then probe them from Site A:

```bash
docker exec -d client-b nc -l 23
docker exec -d client-b nc -l 8080
docker exec client-a nc -zv -w 3 172.28.2.10 23     # blocked (timeout)
docker exec client-a nc -zv -w 3 172.28.2.10 8080   # allowed (open)
```

Encryption check with tcpdump (run each in its own terminal, then ping from client-a):

```bash
docker exec vpn-gateway-a tcpdump -i any -nn udp port 51820   # encrypted UDP only
docker exec vpn-gateway-a tcpdump -i wg0 -nn icmp             # plaintext inside tunnel
docker exec client-a ping -c 5 172.28.2.10
```

## Results

**1. Tunnel up: successful ping across sites and a fresh WireGuard handshake**

3 of 3 pings returned (0% loss) from Site A to Site B, and `wg show` reports a recent handshake with the peer restricted to `10.10.10.2/32, 172.28.2.0/24`.


**2. Zero-trust firewall rules on the gateway**

`FORWARD` policy is `DROP`, with an explicit Telnet drop, stateful `RELATED,ESTABLISHED` accept, and ICMP plus TCP 22/80/443/8080 allowed only toward `wg0`.


**3. Policy enforcement: Telnet blocked, HTTP-alt allowed**

The connection to port 23 timed out while port 8080 succeeded. The Telnet `DROP` rule counter shows the blocked packets.


**4. Traffic generation for the packet capture**

Continuous ping from `client-a` to `client-b` (8/8 replies) used as the traffic source while capturing on the gateway.


## Encryption verification

Run each capture in its own terminal, then generate traffic with a ping from `client-a`:

```bash
docker exec vpn-gateway-a tcpdump -i any -nn udp port 51820   # underlay: encrypted UDP only
docker exec vpn-gateway-a tcpdump -i wg0 -nn icmp             # inside tunnel: plaintext ICMP
docker exec client-a ping -c 8 172.28.2.10
```

The capture on the transit side shows only opaque UDP 51820 packets between `172.28.0.2` and `172.28.0.3`, while the `wg0` interface shows the same pings as readable ICMP. The contrast confirms the data is encrypted in transit.

## What I learned

- How WireGuard peers and `AllowedIPs` define a cryptographic routing boundary
- Building a default-deny firewall with stateful rules
- Verifying encryption by comparing captures on the tunnel interface and the underlay
- Why a site-to-site VPN needs a gateway on both ends (the original lab design only had one)

## Security notes

Private keys are generated locally by `setup.sh` and excluded from the repo via `.gitignore`. This is a lab environment and not production hardened.
