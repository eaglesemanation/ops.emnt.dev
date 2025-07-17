# Backup test playbook

Step by step procedure to verify that backups are working and recovery is possible. Should be done on regular basis to avoid any oopsies when everything is on fire.

## Postgres backups

1. Deploy Crossplane resources for backup buckets and a Postgres instance: `kubectl apply -f backup-test/postgres-init.k8s.yaml`
2. Attach to postgres instance shell, run `psql -d test` and execute following commands:
```postgresql
create table if not exists backuptest (i integer);
insert into backuptest values (1), (2), (3);
select * from backuptest;
-- Should return 1, 2, 3
```
3. Create first backup: `kubectl apply -f backup-test/first-backup.k8s.yaml`
4. Validate that is looks good: `kubectl describe -n=backup-test backup/first-backup`
5. Trigger mirroring over to b2: `kubectl create job -n=backup-test --from=cronjob/local-to-b2-backup-mirror manual-backup-mirror`
6. Validate that with `kubectl describe job -n=backup-test manual-backup-mirror` and `kubectl logs -n=backup-test job/manual-backup-mirror`
6. Add more data into postgres instance:
```postgresql
insert into backuptest values (4);
select * from backuptest;
-- Should return 1, 2, 3, 4
```
7. Create second backup: `kubectl apply -f backup-test/second-backup.k8s.yaml`
8. Validate that is looks good: `kubectl describe -n=backup-test backup/second-backup`
9. Recreate a new Postgres instance from second backup: `kubectl apply -f backup-test/postgres-recovery.k8s.yaml`
10. Query for values in backuptest table from within `test-pg-recovered`:
```postgresql
select * from backuptest;
-- Should return 1, 2, 3, 4
```
11. Rollback local backups with remote ones: `kubectl create job -n=backup-test --from=cronjob/b2-to-local-recovery remote-backup-recovery`
12. Recreate a new Postgres instance from b2 backups that should only include first one: `kubectl apply -f backup-test/postgres-recovery.k8s.yaml`
13. Query for values in backuptest table from within `test-pg-recovered`:
```postgresql
select * from backuptest;
-- Should return 1, 2, 3
```
14. Clean up: `find backup-test -type f -exec kubectl delete -f {} \;`
