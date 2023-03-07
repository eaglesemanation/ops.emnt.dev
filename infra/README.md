## Infra info
### IP ranges
- MetalLB IP pool: 192.168.25.2 - 192.168.25.9
- DHCP IP pool: 192.168.25.10 - 192.168.25.99
- Talos virtual IP: 192.168.25.100
- Talos machines: 192.168.25.101 - 192.168.25.120
- TrueNAS Scale: 192.168.25.200 - 192.168.25.210

### Bootstrap steps
1. Install TrueNAS Scale, setup storage pool
2. Go through steps in `./terraform`
3. Go through steps in `./talos`
