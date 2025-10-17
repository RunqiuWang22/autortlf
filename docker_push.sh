#!/bin/bash
# =============================================================================
# Docker Push Script for AutoRTLF
# =============================================================================
# Purpose: Push Docker images to registry (Docker Hub, etc.)
# Version: 1.0.0
# Created: 2025-10-16
# Author: AutoRTLF Development Team (Kan Li, Cursor)
# 
# Note: For RStudio Server, we recommend using the official rocker/rstudio:4.4.2
# image instead of our custom RStudio image for better reliability.
# =============================================================================

set -e  # Exit on any error

# Check for required parameters
if [ $# -lt 2 ]; then
    echo "Usage: $0 <DOCKERHUB_USER> <VERSION> [REGISTRY]"
    echo "Example: $0 lkboy2018 1.0.0"
    echo "Example: $0 lkboy2018 1.0.0 ghcr.io"
    exit 1
fi

DOCKERHUB_USER=$1
VERSION=$2
REGISTRY=${3:-"docker.io"}

echo "=== AutoRTLF Docker Push ==="
echo "Registry: $REGISTRY"
echo "User: $DOCKERHUB_USER"
echo "Version: $VERSION"
echo ""

# Check if image exists locally
if ! docker images autortlf:${VERSION} | grep -q autortlf; then
    echo "Error: Image autortlf:${VERSION} not found locally"
    echo "Please build the image first with: ./docker_build.sh ${VERSION}"
    exit 1
fi

# Tag images for registry
echo "Tagging images for registry..."
docker tag autortlf:${VERSION} ${REGISTRY}/${DOCKERHUB_USER}/autortlf:${VERSION}
docker tag autortlf:latest ${REGISTRY}/${DOCKERHUB_USER}/autortlf:latest

echo "✓ Images tagged successfully"
echo ""

# Login to registry (if not already logged in)
echo "Checking registry authentication..."
if ! docker info | grep -q "Username"; then
    echo "Please login to $REGISTRY first:"
    if [ "$REGISTRY" = "docker.io" ]; then
        echo "  docker login"
    else
        echo "  docker login $REGISTRY"
    fi
    echo ""
    read -p "Press Enter to continue after logging in..."
fi

# Push images
echo "Pushing images to registry..."
docker push ${REGISTRY}/${DOCKERHUB_USER}/autortlf:${VERSION}
docker push ${REGISTRY}/${DOCKERHUB_USER}/autortlf:latest

echo "✓ Images pushed successfully"
echo ""

echo "=== Push Complete ==="
echo "Images available at:"
echo "  ${REGISTRY}/${DOCKERHUB_USER}/autortlf:${VERSION}"
echo "  ${REGISTRY}/${DOCKERHUB_USER}/autortlf:latest"
echo ""
echo "Users can now pull with:"
echo "  docker pull ${REGISTRY}/${DOCKERHUB_USER}/autortlf:${VERSION}"
echo ""
echo "Or use in docker-compose:"
echo "  image: ${REGISTRY}/${DOCKERHUB_USER}/autortlf:${VERSION}"
