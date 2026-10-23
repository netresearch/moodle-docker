# Bake definition for the moodle and moodle-nginx images.
# Usage: docker buildx bake -f docker-bake.hcl [target]
# Name the file: without -f, bake also reads compose.yml, which needs the
# passwords from .env.
#
# Published by .github/workflows/docker-build.yml through the shared reusable
# netresearch/.github/.github/workflows/build-container-bake.yml. That workflow
# sets the variables below in its pre-build-command; built locally they stay
# empty and the images get no registry tags.
#
# No cache-from/cache-to here: the reusable adds a GHA cache per target
# (scope = target name) and reads none on the weekly rebuild, so that the base
# image and the Alpine packages are fetched again.

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "REPO" {
  default = "netresearch/moodle-docker"
}

# Branch name, or pr-<number> on a pull request.
variable "REF_TAG" {
  default = ""
}

# Full commit SHA. The image tag uses the first 7 characters.
variable "GIT_SHA" {
  default = ""
}

# "true" on the default branch.
variable "LATEST" {
  default = "false"
}

function "image_tags" {
  params = [image]
  result = compact([
    notequal("", REF_TAG) ? "${REGISTRY}/${REPO}/${image}:${REF_TAG}" : "",
    notequal("", GIT_SHA) ? "${REGISTRY}/${REPO}/${image}:sha-${substr(GIT_SHA, 0, 7)}" : "",
    equal("true", LATEST) ? "${REGISTRY}/${REPO}/${image}:latest" : "",
  ])
}

function "image_labels" {
  params = [title, description]
  result = {
    "org.opencontainers.image.title"       = title
    "org.opencontainers.image.description" = description
    "org.opencontainers.image.vendor"      = "Netresearch DTT GmbH"
    "org.opencontainers.image.source"      = "https://github.com/${REPO}"
    "org.opencontainers.image.licenses"    = "MIT"
    "org.opencontainers.image.revision"    = GIT_SHA
  }
}

group "default" {
  targets = ["moodle", "nginx"]
}

target "moodle" {
  context    = "docker/moodle"
  dockerfile = "Dockerfile"
  platforms  = ["linux/amd64"]
  tags       = image_tags("moodle")
  labels     = image_labels("moodle", "Moodle on PHP-FPM (Alpine)")
}

target "nginx" {
  context    = "docker/nginx"
  dockerfile = "Dockerfile"
  platforms  = ["linux/amd64"]
  tags       = image_tags("moodle-nginx")
  labels     = image_labels("moodle-nginx", "nginx with Brotli for Moodle")
}

# Local images for the checks in docker-build.yml.
target "moodle-test" {
  inherits = ["moodle"]
  tags     = ["moodle:test"]
  output   = ["type=docker"]
}

target "nginx-test" {
  inherits = ["nginx"]
  tags     = ["moodle-nginx:test"]
  output   = ["type=docker"]
}
