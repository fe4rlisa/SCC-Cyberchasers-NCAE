# SCC Cyberchasers - NCAE Spring 2027 (Team 3)

Blue Team prep materials, baseline configurations, and pre-approved automation scripts.

Since the NCAE competition network is intentionally isolated (no public internet, `apt update`, or external DNS), these resources focus entirely on native Linux tools, offline troubleshooting, and local backups. 

> **Notice of Competition Compliance:** All scripts, notes, and templates in this repository are publicly accessible and disclosed in strict accordance with NCAE competition rules.

## Directory Structure

* `/linux-admin` - Baseline triage commands, user/SSH auditing, and UFW firewall rules.
* `/web-server` - Apache2 virtual hosts, SSL/HTTPS (Port 443) setups, and file permissions.
* `/networking` - MikroTik RouterOS cheat sheets, internal routing, and NAT.
* `/approved-scripts` - Automated baseline and triage scripts submitted for organizer approval.

## Game Day Deployment (Air-Gapped)

Since a standard `git clone` from external GitHub will fail on the competition network, all automation in the `/approved-scripts` directory must be deployed via the competition's approved ingest method (permitted physical media, internal Git mirror, or direct console transfer).

## Team 3 Golden Rules

1. **Scoring over paranoia:** A perfectly locked-down server that blocks the scoring engine earns 0 points. Do not blindly disable SSH, Apache, Postgres, or SMB.
2. **Snapshot before editing:** Always back up your configurations before changing them. 
   `sudo cp -r /etc /root/etc_backup_initial`
3. **Verify before restarting:** Never restart a service without checking your syntax first (e.g., `sudo sshd -t` or `sudo apache2ctl configtest`). Don't lock yourself out.
