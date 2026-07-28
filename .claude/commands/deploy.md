---
description: Deploy the challenge.osarchers.co.uk subdomain to its live FTP host
---

Deploy the `challenge.osarchers.co.uk/` folder (only that subdomain — nothing else in this repo) over FTP using `deploy/deploy.ps1`. Follow these steps in order — do not skip the confirmation step, this pushes to a live production site.

1. Check that `challenge.osarchers.co.uk/.env` exists. If it doesn't, tell the user to copy `challenge.osarchers.co.uk/.env.example` to `challenge.osarchers.co.uk/.env` and fill in `FTP_HOST`/`FTP_USER`/`FTP_PASSWORD` (and `FTP_REMOTE_ROOT` if not deploying to the account's root), then stop — do not proceed further.

2. Run a dry run:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File deploy/deploy.ps1
   ```
   This never touches the network — it only diffs local files against `.deploy-manifest.json` from the last successful deploy.

3. If the dry run reports nothing to deploy, tell the user the remote is already up to date and stop.

4. Otherwise, summarize the plan for the user: counts of new/changed/deleted files, and the actual filenames (if the list is long, show it in full anyway — the user needs to see exactly what's about to go live). Then ask them to confirm before proceeding.

5. Only after explicit confirmation, run:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File deploy/deploy.ps1 -Apply
   ```

6. Report the result: files uploaded, deleted, and failed. If anything failed, mention that re-running `/deploy` will automatically retry just the failed files (the manifest only advances for files that succeeded).
