#!/bin/bash
# =============================================================================
# Docker Build Script for AutoRTLF
# =============================================================================
# Purpose: Build and tag Docker images for AutoRTLF
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# =============================================================================

set -e  # Exit on any error

# Default values
VERSION=${1:-latest}
DOCKERHUB_USER=${2:-""}
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo "=== AutoRTLF Docker Build ==="
echo "Version: $VERSION"
echo "Build Date: $BUILD_DATE"
echo "Git Commit: $GIT_COMMIT"
echo ""

# Build the Docker image
echo "Building Docker image..."
docker build \
    --tag autortlf:${VERSION} \
    --tag autortlf:latest \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    --build-arg GIT_COMMIT="${GIT_COMMIT}" \
    --label "org.opencontainers.image.created=${BUILD_DATE}" \
    --label "org.opencontainers.image.version=${VERSION}" \
    --label "org.opencontainers.image.revision=${GIT_COMMIT}" \
    --label "org.opencontainers.image.title=AutoRTLF" \
    --label "org.opencontainers.image.description=Automated Regulatory Tables, Listings, and Figures" \
    .

echo "✓ Docker image built successfully"
echo ""

# Show image information
echo "=== Image Information ==="
docker images autortlf:${VERSION}
echo ""

# If Docker Hub username provided, tag for push
if [ ! -z "$DOCKERHUB_USER" ]; then
    echo "Tagging for Docker Hub push..."
    docker tag autortlf:${VERSION} ${DOCKERHUB_USER}/autortlf:${VERSION}
    docker tag autortlf:latest ${DOCKERHUB_USER}/autortlf:latest
    echo "✓ Tagged for Docker Hub: ${DOCKERHUB_USER}/autortlf:${VERSION}"
    echo ""
    echo "To push to Docker Hub, run:"
    echo "  docker push ${DOCKERHUB_USER}/autortlf:${VERSION}"
    echo "  docker push ${DOCKERHUB_USER}/autortlf:latest"
fi

echo ""
echo "=== Build Complete ==="
echo "To run the container:"
echo "  docker run -it autortlf:${VERSION} bash"
echo ""
echo "To run with docker-compose:"
echo "  docker-compose up -d"
echo ""
echo "To validate the environment:"
echo "  docker run autortlf:${VERSION} Rscript docker_validate.R"
