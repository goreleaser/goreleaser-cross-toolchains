include .env

REGISTRIES         ?= ghcr.io \
docker.io

SUBIMAGES          ?= arm64 \
amd64

TOOLS              := ./scripts/tools.sh

TAG_VERSION        ?= $(shell git describe --tags --abbrev=0)

IMAGE_NAMES        := $(shell $(TOOLS) generate tags cross-toolchains $(TAG_VERSION) "$(REGISTRIES)")

DOCKER_BUILD=docker build

SUBIMAGES ?= arm64 \
amd64

.PHONY: gen-changelog
gen-changelog:
	@echo "generating changelog to changelog"
	./scripts/genchangelog.sh $(shell git describe --tags --abbrev=0) changelog.md

.PHONY: toolchains-%
toolchains-%:
	$(DOCKER_BUILD) --platform=linux/$* $(foreach IMAGE,$(IMAGE_NAMES), -t $(IMAGE)-$*) \
		--build-arg DPKG_ARCH=$(DPKG_ARCH) \
		--build-arg CROSSBUILD_ARCH=$(CROSSBUILD_ARCH) \
		--build-arg OSXCROSS_VERSION="$(OSXCROSS_VERSION)" \
		--build-arg DEBIAN_FRONTEND=$(DEBIAN_FRONTEND) \
		-f Dockerfile .

.PHONY: toolchains
toolchains: $(patsubst %, toolchains-%,$(SUBIMAGES))

.PHONY: docker-push-%
docker-push-%:
	docker push $(IMAGE_NAME)-$(@:docker-push-%=%)

.PHONY: docker-push
docker-push: $(patsubst %, docker-push-%,$(SUBIMAGES))

.PHONY: manifest-create
manifest-create:
	@echo "creating manifest $(IMAGE_NAME)"
	docker manifest rm $(IMAGE_NAME) 2>/dev/null || true
	docker manifest create $(IMAGE_NAME) \
		$(foreach arch,$(SUBIMAGES), $(shell docker inspect $(IMAGE_NAME)-$(arch) | jq -r '.[].RepoDigests | .[0]'))

.PHONY: manifest-push
manifest-push:
	@echo "pushing manifest $(IMAGE_NAME)"
	docker manifest push $(IMAGE_NAME)

.PHONY: tags
tags:
	@echo $(IMAGE_NAME) $(foreach arch,$(SUBIMAGES), $(IMAGE_NAME)-$(arch))

.PHONY: tag
tag:
	@echo $(TAG_VERSION)

.PHONY: release
release: toolchains docker-push manifest-create manifest-push

