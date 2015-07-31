# XenServerBKP

Free backup of host and VMs, with interface interaction.

# Overview

It works wirh scripts and crontab on xenserver host, and flags on xencenter interface.

## Scripts
````shel
#Backup Metadata: Daily 02h
0 2 * * * /usr/local/bin/Backup_Metadata

#Backup Hosts from Pool: Every Sunday 09h
0 9 * * sat /usr/local/bin/Backup_Hosts

#Snapshot VMs: Daily 01h
0 1 * * * /usr/local/bin/Snapshots_Diarios

#Exports das VMs, Weekly Flags as 02h
0 2 * * 7 root /usr/local/bin/Exports_Semanais SUN
0 2 * * 6 root /usr/local/bin/Exports_Semanais SAT
````
