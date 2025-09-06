#!/usr/bin/env bash
set -euo pipefail

# Build, sign, checksum, and zip a Maven Central bundle using Gradle.
# Outputs: build/distributions/central-bundle-<artifactId>-<version>.zip

if [[ ! -f "gradlew" ]]; then
  echo "❌ Gradle wrapper not found. Run from the project root." >&2
  exit 1
fi

PROP_FILE="gradle.properties"
if [[ ! -f "$PROP_FILE" ]]; then
  echo "❌ gradle.properties not found." >&2
  exit 1
fi

read_prop() {
  local key="$1"
  # Read the last occurrence of the key (ignoring comments), trim spaces
  awk -F'=' -v k="$key" '
    $0 !~ /^\s*#/ && $1 ~ "^"k"\s*$" {v=$0} END{gsub(/^\s*[^=]*=\s*/ ,"",v); gsub(/\r?\n/,"",v); gsub(/^\s+|\s+$/ ,"",v); print v}
  ' "$PROP_FILE"
}

GROUP_ID=$(read_prop GROUP)
ARTIFACT_ID=$(read_prop POM_SETTING_ARTIFACT_ID)
VERSION=$(read_prop VERSION_NAME)

GROUP_ID=${GROUP_ID:-unspecified}
ARTIFACT_ID=${ARTIFACT_ID:-unspecified}
VERSION=${VERSION:-unspecified}

echo "🏗️  Building Maven Central package for ${GROUP_ID}:${ARTIFACT_ID}:${VERSION}"

if [[ "$VERSION" == *SNAPSHOT* ]]; then
  echo "❌ Version contains SNAPSHOT. Use a release version for Maven Central." >&2
  exit 2
fi

# Require gpg unless user passes in-memory key props
if ! command -v gpg >/dev/null 2>&1 && [[ -z "${ORG_GRADLE_PROJECT_signingKey:-}" ]]; then
  echo "❌ GPG not found. Install GPG or provide -PsigningKey/-PsigningPassword." >&2
  exit 3
fi

export ORG_GRADLE_PROJECT_useGpgCmd=${ORG_GRADLE_PROJECT_useGpgCmd:-true}

echo "📦 Running Gradle publish to local central-bundle dir..."
./gradlew -PcentralBundle=true -PuseGpgCmd=true \
  publishMavenPublicationToCentralBundleRepository \
  generateCentralBundleChecksums \
  zipCentralBundle --no-daemon --warning-mode=all

ZIP_PATH="build/distributions/central-bundle-${ARTIFACT_ID}-${VERSION}.zip"
if [[ ! -f "$ZIP_PATH" ]]; then
  echo "❌ Expected zip not found at $ZIP_PATH" >&2
  exit 4
fi

echo "✅ Maven Central bundle created: $ZIP_PATH"
echo "\n📄 Upload file: $ZIP_PATH"
echo "🌐 Upload to: https://s01.oss.sonatype.org/ (Central Portal)"
echo "\n📝 Maven coordinates:"
cat <<EOF
<dependency>
    <groupId>${GROUP_ID}</groupId>
    <artifactId>${ARTIFACT_ID}</artifactId>
    <version>${VERSION}</version>
</dependency>
EOF

