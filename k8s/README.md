## Bootstraping Flux CD
### Prerequisites
- sops
- kubectl

### Steps
1. Go to `./bootstrap`
2. Decrypt Flux secrets private key with `sops -d sops-age.sops.yaml > sops-age.yaml`
3. Apply Flux manifests with `kubectl apply -k .`
