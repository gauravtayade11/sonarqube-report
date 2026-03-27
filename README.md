# SonarQube Report Generator

> A shell script that generates a self-contained HTML security & quality report from SonarQube — no extra tooling, no plugins, just `curl` and `sh`.

![Phase](https://img.shields.io/badge/Phase-1%20Manual%20Generation-blue)
![Shell](https://img.shields.io/badge/Shell-POSIX%20sh-lightgrey)
![SonarQube](https://img.shields.io/badge/SonarQube-9.x%20%7C%2010.x-orange)

---

## What it does

DevOps or Security teams need to answer on demand: *"Which projects still have Blocker/High/Security issues open?"*

This script hits the SonarQube REST API, **auto-discovers all projects**, and produces a single self-contained HTML report showing:

| Column | What it measures |
|---|---|
| Blocker | Issues with BLOCKER severity (open/confirmed/reopened) |
| High | Issues with HIGH severity |
| Medium | Issues with MEDIUM severity |
| Security Issues | Vulnerabilities at HIGH or BLOCKER level |
| Hotspots | Security hotspots in TO_REVIEW status |
| Reliability | Reliability issues at HIGH/MEDIUM level |
| Gate Status | Quality Gate result (PASSED / FAILED / WARNING) |

Summary cards at the top give an overall view. Each project links directly to its SonarQube dashboard. Only the table rows scroll — the header stays fixed.

**Sample output:**

![Report Screenshot](docs/assets/report-preview.svg)

---

## Project Structure

```
sonarqube-report/
├── scripts/
│   └── sonar-report.sh          # API calls, data aggregation, report generation
├── templates/
│   └── report.html              # HTML/CSS template with {{PLACEHOLDERS}}
├── examples/
│   └── teams.conf.example       # Configuration example
└── docs/
    ├── sample-report.html       # Preview the report in a browser
    └── assets/
        └── report-preview.svg   # README screenshot
```

---

## Roadmap

| Phase | Status | Description |
|---|---|---|
| **Phase 1** | ✅ Current | Manual — run the script on demand, share HTML files |
| **Phase 2** | Planned | Cron / CI scheduled runs |
| **Phase 3** | Planned | Email delivery — auto-send report to team leads |
| **Phase 4** | Planned | Slack integration — post summary card to team channels |
| **Phase 5** | Planned | Jenkins / Devtron pipeline stage — report as build artifact |

---

## Phase 1 — Manual Generation

### Prerequisites

| Requirement | Notes |
|---|---|
| `sh` / `bash` | Any POSIX shell; tested on macOS zsh, Linux bash, Alpine sh |
| `curl` | Must be installed and in `$PATH` |
| `awk` | Standard on all POSIX systems |
| SonarQube token | Needs **Browse** permission on all projects (or Global Admin) |
| Network access | Machine running the script must reach `SONAR_HOST_URL` |

### 1. Clone the repo

```sh
git clone https://github.com/gauravtayade11/sonarqube-report.git
cd sonarqube-report
```

### 2. Configure the script

Open `scripts/sonar-report.sh` and update the top section:

```sh
SONAR_HOST_URL="https://sonarqube.yourcompany.com"   # your SonarQube URL
SONAR_ADMIN_TOKEN="sqp_xxxxxxxxxxxx"                 # your token
REPORT_NAME="platform"                               # used as report heading and filename
```

> **Token tip:** Generate at *SonarQube → My Account → Security → Tokens*.
> Use type **User Token** with Browse permission, or a **Global Analysis Token** if you have Global Admin.

### 3. Run the script

```sh
sh scripts/sonar-report.sh
```

Expected output:

```
[INFO]    Discovering all projects from SonarQube...
[INFO]      Processing: frontend-web
[INFO]      Processing: auth-service
[INFO]      Processing: payments-api
...
============================================================
  REPORT GENERATED
  Date   : 2026-03-27
  Report : sonarqube-report-platform-2026-03-27.html
============================================================
```

### 4. Share the report

Open the generated `.html` file in any browser — fully self-contained, no external CSS/JS dependencies.

Options for sharing:
- Email as attachment
- Upload to S3 / GCS bucket with a public/signed URL
- Commit to a `reports/` branch and share via GitHub Pages
- Upload to Confluence as an attachment
- Post in a Slack message

---

## Configuration Reference

### REPORT_NAME

```sh
REPORT_NAME="platform"
```

- Used as the report heading and output filename: `sonarqube-report-platform-2026-03-27.html`
- Use lowercase letters, numbers, and hyphens only
- All projects are **auto-discovered** from SonarQube — no need to list project keys manually

### Environment variable override (optional)

Instead of hardcoding the token in the script, export it before running:

```sh
export SONAR_ADMIN_TOKEN="sqp_xxxxxxxxxxxx"
sh scripts/sonar-report.sh
```

### Customising the report layout

Edit `templates/report.html` directly — it uses `{{PLACEHOLDER}}` tokens that the script substitutes at runtime. No changes to the script needed for visual changes.

---

## How it works

1. Fetches all projects from SonarQube using `/api/projects/search?ps=500`
2. For each project, queries three endpoints:

```
GET /api/issues/search               — issue counts by severity/type
GET /api/hotspots/search             — security hotspot counts
GET /api/qualitygates/project_status — quality gate result
```

3. Fills `templates/report.html` using `awk`, replacing `{{PLACEHOLDER}}` tokens with live data

No SonarQube plugins or server-side configuration required.

---

## Troubleshooting

**All counts show 0**
- Check that `SONAR_ADMIN_TOKEN` is correct and not expired
- Verify connectivity: `curl -u "$SONAR_ADMIN_TOKEN:" "$SONAR_HOST_URL/api/system/status"`

**No projects found**
- Token may lack Browse permission — try a Global Admin token
- Verify `SONAR_HOST_URL` has no trailing slash

**`UNKNOWN` quality gate**
- Token lacks Browse permission on that specific project

---

## Contributing

1. Fork the repo
2. Create a branch: `git checkout -b feature/your-feature`
3. Commit your changes
4. Open a pull request

---

## License

MIT — see [LICENSE](LICENSE)

---

*Feedback and PRs welcome — [github.com/gauravtayade11/sonarqube-report](https://github.com/gauravtayade11/sonarqube-report)*
