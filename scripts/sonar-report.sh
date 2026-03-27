#!/bin/sh
# ============================================================
# Script      : SonarQube Progress Report
# Description : Generates per-team HTML report showing
#               security and quality issues
# Usage       : sh sonar-report.sh
# Output      : sonarqube-report-[team]-[date].html
# Repo        : https://github.com/gauravtayade11/sonarqube-report
# ============================================================

SCRIPT_DIR=$(dirname "$0")
TEMPLATE="$SCRIPT_DIR/../templates/report.html"

# ── Global Configuration ──────────────────────────────────────
SONAR_HOST_URL="https://sonarqube.yourcompany.com"
SONAR_ADMIN_TOKEN="your-admin-token-here"
REPORT_DATE=$(date '+%Y-%m-%d')

# ── Report Configuration ──────────────────────────────────────
# Report name — used as the report heading and output filename
# All projects are auto-discovered from SonarQube
REPORT_NAME="platform"

# ── Colors ────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { echo "${BLUE}[INFO]${NC}    $1"; }
log_success() { echo "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo "${YELLOW}[WARN]${NC}    $1"; }

# ── Helper: Get Issue Count ───────────────────────────────────
get_issue_count() {
  PROJECT=$1
  SEVERITY=$2
  TYPE=$3

  if [ "$TYPE" = "hotspot" ]; then
    COUNT=$(curl --silent \
      -u "$SONAR_ADMIN_TOKEN:" \
      "$SONAR_HOST_URL/api/hotspots/search?projectKey=$PROJECT&status=TO_REVIEW&ps=1" \
      | grep -o '"total":[0-9]*' \
      | head -1 \
      | cut -d':' -f2)
  elif [ "$TYPE" = "squality" ]; then
    COUNT=$(curl --silent \
      -u "$SONAR_ADMIN_TOKEN:" \
      "$SONAR_HOST_URL/api/issues/search?projectKeys=$PROJECT&types=VULNERABILITY&severities=$SEVERITY&statuses=OPEN,CONFIRMED,REOPENED&ps=1" \
      | grep -o '"total":[0-9]*' \
      | head -1 \
      | cut -d':' -f2)
  else
    COUNT=$(curl --silent \
      -u "$SONAR_ADMIN_TOKEN:" \
      "$SONAR_HOST_URL/api/issues/search?projectKeys=$PROJECT&severities=$SEVERITY&statuses=OPEN,CONFIRMED,REOPENED&ps=1" \
      | grep -o '"total":[0-9]*' \
      | head -1 \
      | cut -d':' -f2)
  fi

  echo "${COUNT:-0}"
}

# ── Helper: Get QG Status ─────────────────────────────────────
get_qg_status() {
  PROJECT=$1
  STATUS=$(curl --silent \
    -u "$SONAR_ADMIN_TOKEN:" \
    "$SONAR_HOST_URL/api/qualitygates/project_status?projectKey=$PROJECT" \
    | grep -o '"status":"[^"]*"' \
    | head -1 \
    | cut -d'"' -f4)
  echo "${STATUS:-UNKNOWN}"
}

# ── Helper: Status Badge ──────────────────────────────────────
get_badge() {
  STATUS=$1
  case "$STATUS" in
    "OK")      echo '<span class="badge pass">PASSED</span>' ;;
    "ERROR")   echo '<span class="badge fail">FAILED</span>' ;;
    "WARN")    echo '<span class="badge warn">WARNING</span>' ;;
    *)         echo '<span class="badge unknown">UNKNOWN</span>' ;;
  esac
}

# ── Helper: Count Cell ────────────────────────────────────────
get_cell() {
  COUNT=$1
  if [ "$COUNT" -gt 0 ]; then
    echo "<td class='count-red'>$COUNT</td>"
  else
    echo "<td class='count-green'>✓</td>"
  fi
}

# ── Generate Report ───────────────────────────────────────────
log_info "Discovering all projects from SonarQube..."

ALL_PROJECTS=$(curl --silent \
  -u "$SONAR_ADMIN_TOKEN:" \
  "$SONAR_HOST_URL/api/projects/search?ps=500" \
  | grep -o '"key":"[^"]*"' \
  | cut -d'"' -f4)

if [ -z "$ALL_PROJECTS" ]; then
  log_warn "No projects found — check your token and SONAR_HOST_URL"
  exit 1
fi

REPORT_FILE="sonarqube-report-${REPORT_NAME}-${REPORT_DATE}.html"
PROJECT_ROWS=""
TEAM_BLOCKER=0
TEAM_HIGH=0
TEAM_MEDIUM=0
TEAM_SECURITY=0
TEAM_HOTSPOTS=0
TEAM_RELIABILITY=0
TEAM_PASSED=0
TEAM_FAILED=0

for PROJECT_KEY in $ALL_PROJECTS; do

    log_info "  Processing: $PROJECT_KEY"

    # Get project name
    PROJECT_NAME=$(curl --silent \
      -u "$SONAR_ADMIN_TOKEN:" \
      "$SONAR_HOST_URL/api/projects/search?projects=$PROJECT_KEY" \
      | grep -o '"name":"[^"]*"' \
      | head -1 \
      | cut -d'"' -f4)
    PROJECT_NAME="${PROJECT_NAME:-$PROJECT_KEY}"

    # Get counts
    BLOCKER=$(get_issue_count "$PROJECT_KEY" "BLOCKER" "severity")
    HIGH=$(get_issue_count "$PROJECT_KEY" "HIGH" "severity")
    MEDIUM=$(get_issue_count "$PROJECT_KEY" "MEDIUM" "severity")
    SECURITY=$(get_issue_count "$PROJECT_KEY" "HIGH,BLOCKER" "squality")
    HOTSPOTS=$(get_issue_count "$PROJECT_KEY" "" "hotspot")
    RELIABILITY=$(get_issue_count "$PROJECT_KEY" "HIGH,MEDIUM" "squality")
    QG_STATUS=$(get_qg_status "$PROJECT_KEY")

    # Update team totals
    TEAM_BLOCKER=$((TEAM_BLOCKER + BLOCKER))
    TEAM_HIGH=$((TEAM_HIGH + HIGH))
    TEAM_MEDIUM=$((TEAM_MEDIUM + MEDIUM))
    TEAM_SECURITY=$((TEAM_SECURITY + SECURITY))
    TEAM_HOTSPOTS=$((TEAM_HOTSPOTS + HOTSPOTS))
    TEAM_RELIABILITY=$((TEAM_RELIABILITY + RELIABILITY))

    if [ "$QG_STATUS" = "OK" ]; then
      TEAM_PASSED=$((TEAM_PASSED + 1))
    else
      TEAM_FAILED=$((TEAM_FAILED + 1))
    fi

    # Build row
    BADGE=$(get_badge "$QG_STATUS")
    B_CELL=$(get_cell "$BLOCKER")
    H_CELL=$(get_cell "$HIGH")
    M_CELL=$(get_cell "$MEDIUM")
    S_CELL=$(get_cell "$SECURITY")
    HS_CELL=$(get_cell "$HOTSPOTS")
    R_CELL=$(get_cell "$RELIABILITY")

    PROJECT_ROWS="$PROJECT_ROWS
    <tr>
      <td><strong>$PROJECT_NAME</strong><br><small>$PROJECT_KEY</small></td>
      $B_CELL
      $H_CELL
      $M_CELL
      $S_CELL
      $HS_CELL
      $R_CELL
      <td>$BADGE</td>
      <td><a href='$SONAR_HOST_URL/dashboard?id=$PROJECT_KEY' target='_blank'>View →</a></td>
    </tr>"

  done

# ── Generate HTML from template ───────────────────────────────
REPORT_DISPLAY=$(echo "$REPORT_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')

ROWS_TMP=$(mktemp)
printf '%s\n' "$PROJECT_ROWS" > "$ROWS_TMP"

awk -v team="$REPORT_DISPLAY" \
    -v date="$REPORT_DATE" \
    -v url="$SONAR_HOST_URL" \
    -v blocker="$TEAM_BLOCKER" \
    -v high="$TEAM_HIGH" \
    -v medium="$TEAM_MEDIUM" \
    -v security="$TEAM_SECURITY" \
    -v hotspots="$TEAM_HOTSPOTS" \
    -v failed="$TEAM_FAILED" \
    -v passed="$TEAM_PASSED" \
    -v rowsfile="$ROWS_TMP" \
    '
    /\{\{PROJECT_ROWS\}\}/ {
      while ((getline line < rowsfile) > 0) print line
      next
    }
    {
      gsub(/\{\{TEAM_DISPLAY\}\}/,  team)
      gsub(/\{\{REPORT_DATE\}\}/,   date)
      gsub(/\{\{SONAR_HOST_URL\}\}/, url)
      gsub(/\{\{TEAM_BLOCKER\}\}/,  blocker)
      gsub(/\{\{TEAM_HIGH\}\}/,     high)
      gsub(/\{\{TEAM_MEDIUM\}\}/,   medium)
      gsub(/\{\{TEAM_SECURITY\}\}/, security)
      gsub(/\{\{TEAM_HOTSPOTS\}\}/, hotspots)
      gsub(/\{\{TEAM_FAILED\}\}/,   failed)
      gsub(/\{\{TEAM_PASSED\}\}/,   passed)
      print
    }
    ' "$TEMPLATE" > "$REPORT_FILE"

rm -f "$ROWS_TMP"

echo ""
echo "============================================================"
echo "  REPORT GENERATED"
echo "  Date   : $REPORT_DATE"
echo "  Report : $REPORT_FILE"
echo "============================================================"
