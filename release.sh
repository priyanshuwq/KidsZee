#!/usr/bin/env bash
#
# release.sh — Build, version, commit, tag, push, and publish a GitHub release.
#
# Usage:
#   ./release.sh
#
# Prerequisites: flutter, git, gh (authenticated)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { printf "${GREEN}[release]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[release]${NC} %s\n" "$1"; }
abort() { printf "${RED}[release] ABORT:${NC} %s\n" "$1" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Pre-flight checks
# ---------------------------------------------------------------------------

command -v flutter >/dev/null 2>&1 || abort "flutter is not installed."
command -v git     >/dev/null 2>&1 || abort "git is not installed."
command -v gh      >/dev/null 2>&1 || abort "gh CLI is not installed."

BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT_BRANCH="$BRANCH"

if [[ -n "$(git status --porcelain)" ]]; then
    abort "Working directory is not clean. Commit or stash your changes first."
fi

log "On branch: $BRANCH"

# ---------------------------------------------------------------------------
# 2. Read current version from pubspec.yaml
# ---------------------------------------------------------------------------

PUBSPEC="pubspec.yaml"
[[ -f "$PUBSPEC" ]] || abort "pubspec.yaml not found. Run this from the project root."

CURRENT_VERSION=$(grep -E '^version:' "$PUBSPEC" | head -1 | sed 's/version: *//')
CURRENT_SEMVER=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
CURRENT_BUILD=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

log "Current version: $CURRENT_VERSION"

# ---------------------------------------------------------------------------
# 3. Prompt for new version
# ---------------------------------------------------------------------------

read -rp "New version (e.g. 1.1.0): " NEW_VERSION

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    abort "Invalid version format. Use X.Y.Z (e.g. 1.1.0)"
fi

if git tag -l "v$NEW_VERSION" | grep -q "v$NEW_VERSION"; then
    abort "Tag v$NEW_VERSION already exists."
fi

NEW_BUILD=$((CURRENT_BUILD + 1))
FULL_VERSION="${NEW_VERSION}+${NEW_BUILD}"

log "New version: $FULL_VERSION (tag: v$NEW_VERSION)"

# ---------------------------------------------------------------------------
# 4. Prompt for changelog entries
# ---------------------------------------------------------------------------

echo ""
echo "Enter changelog entries (one per line, empty line to finish):"
CHANGELOG_ENTRIES=""
while IFS= read -rp "  - " line; do
    [[ -z "$line" ]] && break
    CHANGELOG_ENTRIES="${CHANGELOG_ENTRIES}- ${line}\n"
done

if [[ -z "$CHANGELOG_ENTRIES" ]]; then
    abort "At least one changelog entry is required."
fi

TODAY=$(date +%Y-%m-%d)
CHANGELOG_SECTION="## v${NEW_VERSION} (${TODAY})\n\n${CHANGELOG_ENTRIES}"

echo ""
log "Changelog preview:"
echo -e "$CHANGELOG_SECTION"
echo ""

read -rp "Proceed? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || abort "Cancelled by user."

# ---------------------------------------------------------------------------
# 5. Analyze
# ---------------------------------------------------------------------------

log "Running flutter analyze..."
if ! flutter analyze; then
    abort "flutter analyze found issues. Fix them before releasing."
fi

# ---------------------------------------------------------------------------
# 6. Build APK
# ---------------------------------------------------------------------------

log "Building release APK..."
if ! flutter build apk --release; then
    abort "APK build failed."
fi

APK_BUILD_PATH="build/app/outputs/flutter-apk/app-release.apk"
[[ -f "$APK_BUILD_PATH" ]] || abort "APK not found at $APK_BUILD_PATH"

APK_PATH="build/app/outputs/flutter-apk/KidsZee.apk"
cp "$APK_BUILD_PATH" "$APK_PATH"

APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
log "APK built: $APK_PATH ($APK_SIZE)"

# ---------------------------------------------------------------------------
# 7. Update pubspec.yaml version
# ---------------------------------------------------------------------------

log "Updating pubspec.yaml version to $FULL_VERSION..."
sed -i "s/^version: .*/version: $FULL_VERSION/" "$PUBSPEC"

# ---------------------------------------------------------------------------
# 8. Update CHANGELOG.md
# ---------------------------------------------------------------------------

CHANGELOG_FILE="CHANGELOG.md"

if [[ -f "$CHANGELOG_FILE" ]]; then
    # Prepend new section after the "# Changelog" header
    TEMP_FILE=$(mktemp)
    echo "# Changelog" > "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    echo -e "$CHANGELOG_SECTION" >> "$TEMP_FILE"
    # Append everything after the first line of the old changelog
    tail -n +2 "$CHANGELOG_FILE" >> "$TEMP_FILE"
    mv "$TEMP_FILE" "$CHANGELOG_FILE"
else
    echo "# Changelog" > "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
    echo -e "$CHANGELOG_SECTION" >> "$TEMP_FILE"
fi

log "CHANGELOG.md updated."

# ---------------------------------------------------------------------------
# 9. Git commit and tag
# ---------------------------------------------------------------------------

log "Committing..."
git add -A
git commit -m "release: v${NEW_VERSION}"
git tag "v${NEW_VERSION}"

log "Pushing to origin/$BRANCH..."
git push origin "$BRANCH" --tags

# ---------------------------------------------------------------------------
# 10. Create GitHub Release
# ---------------------------------------------------------------------------

log "Creating GitHub release..."

NOTES_FILE=$(mktemp)
echo -e "$CHANGELOG_ENTRIES" > "$NOTES_FILE"

gh release create "v${NEW_VERSION}" "$APK_PATH" \
    --title "v${NEW_VERSION}" \
    --notes-file "$NOTES_FILE"

rm -f "$NOTES_FILE"

echo ""
log "Release v${NEW_VERSION} published."
log "https://github.com/$(gh repo view --json nameWithOwner -q '.nameWithOwner')/releases/tag/v${NEW_VERSION}"
