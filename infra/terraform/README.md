## Setting up VMs on TrueNAS Scale
### Prerequisites
- terraform
- sops
- NAS with TrueNAS Scale installed

### Preparation
#### Setup bridged interface with static IP
- TODO: Write docs for that

#### Setup LAN CA and create a cert for TrueNAS
1. Create CA with Subject Alternate Names set to `local` in *Credentials > Certificates*
2. Create a CSR with SAN set to `emnt-nas.local` and sign it with CA
3. Copy CA cert by pressing on cert and selecting *View/Download Certificate*
4. Save it as `cert.pem` in appropriate location on local system, on Fedora Linux that would be `/etc/pki/ca-trust/source/anchors`
5. Go to *Network* and verify that Hostname is set to `emnt-nas`
6. Go to *System Settings > General* and update GUI SSL Certificate to new cert

#### Enable S3 on TrueNAS
1. Create Datavol for S3 storage
2. Enable S3 service, setup secure access key and secure key (for me already stored in `pass`)
3. Go to MinIO web UI `http://emnt-nas.local:9001/`
4. In *Settings > Region* set *Server Location* to `us-west-1`
5. Create a `terraform-state` bucket
6. Add a policy that will only allow read-write access to that bucket:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketLocation",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads"
            ],
            "Resource": [
                "arn:aws:s3:::terraform-state"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:DeleteObject",
                "s3:GetObject",
                "s3:ListMultipartUploadParts",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::terraform-state/*"
            ]
        }
    ]
}
```
7. Decrypt S3 creds file with `sops -d s3creds.sops.toml > s3creds.toml`
8. Create user with creds from previous step and attach policy from step earlier
9. Go back to TrueNAS services settings, and enable TLS for S3. Currently this step breaks MinIO UI in combination with mDNS, that's why it's done after config

#### Creating VMs
- This is not ready, terraform provider does not support Bluefin release of TrueNAS Scale yet. Meanwhile deploy manually

### Troubleshooting
> Error refreshing state: RequestTimeTooSkewed

It's possible thats your BIOS/UEFI clock on TrueNAS machine is so out of sync with real time, that NTP cannot sync it.
