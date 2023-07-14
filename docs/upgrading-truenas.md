# Updating TrueNAS

## Post Upgrade

### MinIO patch

Current implementation of MinIO for TrueNAS does not allow to overwrite port for `MINIO_SERVER_URI` env var, which breaks ingress setup. To fix this:

1. Open TrueNAS Console, go to System Settings > Shell
2. Edit `/usr/bin/minio-truenas`
3. Change from this
```python
os.environ["MINIO_SERVER_URL"] = f'https://{s3["tls_server_uri"]:s3["bindport"]}'
```
To this
```python
os.environ["MINIO_SERVER_URL"] = f'https://{s3["tls_server_uri"]}'
```
4. Open System Settings > Services
5. Restart S3 service
