#!/usr/bin/env bash

set -e

# Configuration
ARCHS=("x86_64" "arm64" "arm")
SOURCE_REPO="registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper"
DEST_REPO="ghcr.io/$REPO_NAME"

# Install necessary tools for local development
if [ "$PREPARE" ]; then
  apt update && apt install -y skopeo jq
  go install github.com/estesp/manifest-tool/v2/cmd/manifest-tool@latest
  go install gitlab.com/gitlab-org/cli/cmd/glab@latest
fi

# Log environment and directory contents
env && ls -Alh

# Fetch existing releases and sort them by version (latest first)
EXISTING_RELEASES=$(git tag | sort -Vr)
echo "Existing Releases: $EXISTING_RELEASES"

# Fetch new releases from glab, sort them by version (latest first), and filter out existing releases
GLAB_RELEASES=$(glab release list -R "gitlab-org/gitlab-runner" | grep -E "^v.*" | awk '{ print $1 }' | sort -Vr)
echo "Found Gitlab Releases: $GLAB_RELEASES"

# Compare lists and determine new releases
set +e
if [ -n "$EXISTING_RELEASES" ]; then
  NEW_RELEASES=$(echo "$GLAB_RELEASES" | tr ' ' '\n' | grep -vFxf <(echo "$EXISTING_RELEASES" | tr ' ' '\n'))
  # Exit early if there are no new releases to process
  [ -z "$NEW_RELEASES" ] && { echo "No new releases to process. Exiting."; exit 0; }
else
  NEW_RELEASES=$GLAB_RELEASES
fi
set -e
echo "New Releases: $NEW_RELEASES"

# Function to copy images for a specific architecture
copy_image() {
  local VERSION=$1 ARCH=$2 DESTARCH=${2/x86_64/amd64}
  echo "Creating $DESTARCH image at $DEST_REPO:alpine-$DESTARCH-$VERSION"
  skopeo copy --multi-arch all --dest-creds="$:$GITHUB_TOKEN" \
    "docker://$SOURCE_REPO:alpine-latest-$ARCH-$VERSION" \
    "docker://$DEST_REPO:alpine-$DESTARCH-$VERSION"
}

# Function to generate manifest for a specific version
generate_manifest() {
  echo "Creating Manifest for $DEST_REPO:alpine-$1"
  manifest-tool push from-args \
    --platforms linux/amd64,linux/arm64,linux/arm \
    --template "$DEST_REPO:alpine-ARCH-$1" \
    --target "$DEST_REPO:alpine-$1"
}

# Process each new release (sorted by version, latest first)
for VERSION in $NEW_RELEASES; do
  echo "Processing version $VERSION..."
  for ARCH in "${ARCHS[@]}"; do copy_image "$VERSION" "$ARCH" & done
  wait # Wait for all background jobs to finish
  generate_manifest "$VERSION"
  gh release create "$VERSION"
done
