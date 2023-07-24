# Linux Restic Backup

This repository contains scripts to install and configure restic+b2 to perform Linux backups.

## Installing

The repository contains an `install.sh` script that will perform installation of Restic.

### Installer Options

The installer contains a few options that allow easily declaring custom include and exclude lists as well as custom bucket names.

* -i (optional) -- Path to the incudes file (default: includes.list).
* -e (optional) -- Path to the excludes file (default: excludes.list).
* -b (optional) -- Bucket name to backup to (default: restic-linux).

### Installing restic-backup

1. Customize the `includes.list` and `excludes.list`
    - If a file is in the includes list **and** excludes list it will be included.
    - This does not include subfolders Ex: includes has `/home` but excludes has `/home/someuser`. In this case `/home/someuser` will not be backed up but all other folders in `/home` that aren't excluded will.
1. Run `install.sh` as root
2. Decide the repo name
    - `Do you wish to keep the repo name set to b2:restic-linux:morocco-mole/repo? (Y/n)`
    - Will always default to `b2:$BUCKET_NAME:$HOSTNAME/repo`.
    - `$BUCKET_NAME` can be configured with the `-b` flag
3. Enter the b2 Key ID for the bucket that will be used.
4. Enter the b2 App Key that corresponds to the Key ID given.
5. Restic will download from GitHub
6. The specified or default includes/excludes will be copied to `/opt/restic`

## Backing Up

Backups can be run by executing `/opt/restic/restic-backup`. This will run the backup with the default values. 

### Backup Options

Please see `restic-backup -h` for details on options.

### Scheduling Backups

`restic-backup` can be cron'd like any other command.

```
0 0 * * * /opt/restic/restic-backup
```

## Restoring

To restore files the restic environment variables must first be sourced.

```
source /etc/restic-environment
```

### Exploring Backups

Restic uses a snapshot system. List he snapshots using the following.
```
restic snapshots
```

The latest snapshot has a special name of `latest`.

### Restoring Snapshots

To restore a snapshot to a target folder is a simple command.

```
restic restore $SNAPSHOT_ID --target $RESTORE_LOCATION --path $TO_RESTORE
```

There are many options to restore specific files and paths. Please see the [restic documentation](https://restic.readthedocs.io/en/stable/050_restore.html#restoring-from-a-snapshot) for more thorough details.
