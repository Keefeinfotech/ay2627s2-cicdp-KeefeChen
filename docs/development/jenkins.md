# Jenkins (optional, local CI/CD)

This project ships with two pipelines:

| | `.github/workflows/ci.yml` | Root `Jenkinsfile` |
|---|---|---|
| Where | GitHub-hosted runners | Jenkins running locally in Docker |
| Trigger | Push / pull request / manual | Manual build (or webhook/poll) |
| Gate | Full quality gate (security scans, CodeQL, SonarCloud, E2E, …) | Backend + frontend quality gate, web build, local redeploy |
| Deploy | `deploy-production.yml` (Render) | `docker compose up -d --build` on this machine |

GitHub Actions remains the remote gate; Jenkins runs the same checks on your
own machine and can rebuild and restart the local stack. Both files live in
the repo, so the Jenkins job is a *Pipeline script from SCM* job.

## What Jenkins does here

Jenkins is a self-hosted automation server. For this project it:

1. Pulls the repository from GitHub,
2. runs the backend gate — `npm ci`, lint + typecheck, tests with coverage, build,
3. runs the frontend gate — `flutter pub get`, format check, `flutter analyze`,
   tests with coverage, the 60% line-coverage gate, web release build,
4. optionally redeploys the local stack (`docker compose build` + `up -d`)
   and waits for the health checks, behind a manual approval,
5. archives build output and coverage reports as build artifacts,
6. records a green/red history you can show as evidence of CI/CD.

The old `backend/Jenkinsfile` is the original backend-only pipeline used
during development. The root `Jenkinsfile` supersedes it; delete the old one
when you are confident in the new one.

## Prerequisites

- Docker Desktop with the WSL2 backend, running.
- This repository cloned locally.
- ~4 GB free disk for the Jenkins image (the Flutter SDK alone is ~2.5 GB).
- Internet access on first build (downloads Node.js 22 and Flutter 3.47.8).

## 1. Start Jenkins

```powershell
cd "C:\Users\chenl\OneDrive\Desktop\CICD stuff\Assignment Submission\CA1_CICD_Project"
docker compose --profile jenkins up -d --build
```

The first build takes a while (it downloads and precaches Flutter). After
that, startup takes seconds. UI: <http://localhost:8081> (host port 8081
because the frontend owns 8080). Stop it with:

```powershell
docker compose --profile jenkins down     # keeps jenkins_home volume
```

## 2. Unlock Jenkins (first run only)

```powershell
docker exec auxilia-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Paste it into the unlock page, choose **Install suggested plugins**, create
your admin user, and keep the default Jenkins URL.

The suggested set already includes everything the pipeline needs (Pipeline,
Git, GitHub, credentials). No extra plugins are required.

## 3. Create the job

1. Dashboard → **New Item** → name it `auxilia-cicd` → **Pipeline** → OK.
2. Under **Build Triggers**:
   - Tick **GitHub hook trigger for GITScm polling** if you have a public
     URL that can reach Jenkins (see §5), **or**
   - Tick **Poll SCM** with `* * * * *` to check GitHub every minute,
     **or** nothing at all and click **Build Now** manually.
3. Under **Pipeline**:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen.git`
   - Credentials: none needed for a public repo; add a GitHub PAT if it is private
   - Branch Specifier: `*/feature/enterprise-cicd-pipeline` (or `*/main` once merged)
   - Script Path: `Jenkinsfile`
4. Save → **Build Now**.

A green build runs: Checkout → Backend (install/lint/test/build) → Frontend
(install/format/analyze/test/coverage gate/build web) → skips Deploy unless
gated on `main`/`master` or the **DEPLOY** parameter was ticked → archives
artifacts.

## 4. The deploy stage

Deploy is **opt-in and approved**:

- It runs automatically on `main`/`master` builds, or on any branch when you
  tick **DEPLOY** in "Build with Parameters".
- An `input` approval asks you to confirm before the running stack is
  rebuilt — the stack briefly restarts.
- It mounts the host Docker socket (`/var/run/docker.sock`) so Jenkins can
  run `docker compose build && docker compose up -d` on your machine, then
  polls `http://localhost:3000/api/health` and `http://localhost:8080/`.

Security notes: mounting the socket gives the Jenkins container full control
of your Docker engine (it can see and replace every container). For a local
development Jenkins this is acceptable; for anything shared/remote, remove
the mount or replace the deploy stage with a webhook. Never commit Jenkins
secrets — the pipeline needs none. The initial admin password and any PATs
live in `jenkins_home` (a Docker volume), not in the repository.

## 5. Triggering Jenkins from GitHub (optional)

GitHub cannot reach `localhost`, so automatic builds need one of:

- **Poll SCM** (`* * * * *`) — simplest, one minute latency, no public URL;
- **ngrok / Cloudflare Tunnel**: `ngrok http 8081`, then add
  `https://<id>.ngrok.io/github-webhook/` as a webhook in
  GitHub → repo → Settings → Webhooks (content type `application/json`,
  just the `push` event) and tick **GitHub hook trigger** in the job.

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| `docker: permission denied` on the socket (Linux hosts) | `sudo usermod -aG docker jenkins` is irrelevant here; on Docker Desktop/WSL2 the socket is normally world-writable. If not, add `user: "root"` to the `jenkins` service in `docker-compose.yml` |
| Port 8081 already in use | Change the published port in `docker-compose.yml` (e.g. `"9081:8080"`) and adjust the URLs above |
| First build hangs on `flutter pub get` / `precache` | The SDK downloads ~1 GB on first use; watch the console log, don't kill it |
| `flutter: fatal: detected dubious ownership in repository at '/opt/flutter'` | The image sets `git config --system --add safe.directory /opt/flutter`; if you bypass the image, set it for the jenkins user |
| `npm ci` needs a proxy | Set `npm_config_proxy`/`npm_config_https_proxy` as secure Jenkins credentials → environment variables on the job |
| Pipeline can't find `docker-compose.yml` | The deploy stage runs at the workspace root; keep `Script Path: Jenkinsfile` |
| Build artifacts missing | `archiveArtifacts` globs are anchored at the workspace root: `backend/dist/**` etc. |
| Jenkins container can't resolve GitHub | Check VPN/DNS; retry with `docker compose --profile jenkins restart jenkins` |

## 7. What a build looks like

```
Checkout
Backend
  Install Dependencies ......... ~30s
  Lint and Type Check .......... ~20s
  Automated Tests .............. ~30-60s (25 integration + unit + functional)
  Build ........................ ~10s
Frontend
  Install Dependencies ......... ~20s
  Format Check ................. ~5s
  Static Analysis .............. ~30s
  Automated Tests .............. ~1-3 min
  Coverage Gate (60%) .......... <1s
  Build Web .................... ~1-2 min
Deploy (Local)  [approval → rebuild → wait for health]
```

Total: roughly 4–8 minutes on a warm Docker Desktop.
