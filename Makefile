include .env

REGISTRY           ?= ghcr.io
TAG_VERSION        ?= $(shell git describe --tags --abbrev=0)
IMAGE_NAME         := goreleaser/goreleaser-cross-toolchains:$(TAG_VERSION)

ifneq ($(REGISTRY),)
	IMAGE_NAME     := $(REGISTRY)/$(IMAGE_NAME)
endif

DOCKER_BUILD=docker build

SUBIMAGES ?= amd64 \
arm64

.PHONY: gen-changelog
gen-changelog:
	@echo "generating changelog to changelog"
	./scripts/genchangelog.sh $(shell git describe --tags --abbrev=0) changelog.md

.PHONY: toolchain-%
toolchain-%:
	@echo "building $(IMAGE_NAME)-$(@:toolchain-%=%)"
	$(DOCKER_BUILD) --platform=linux/$(@:toolchain-%=%) -t $(IMAGE_NAME)-$(@:toolchain-%=%) \
		--build-arg DPKG_ARCH=$(DPKG_ARCH) \
		--build-arg CROSSBUILD_ARCH=$(CROSSBUILD_ARCH) \
		--build-arg OSXCROSS_VERSION="$(OSXCROSS_VERSION)" \
		--build-arg DEBIAN_FRONTEND=$(DEBIAN_FRONTEND) \
		-f Dockerfile .

.PHONY: toolchains
toolchains: $(patsubst %, toolchain-%,$(SUBIMAGES))

.PHONY: docker-push-%
docker-push-%:
	docker push $(IMAGE_NAME)-$(@:docker-push-%=%)

.PHONY: docker-push
docker-push: $(patsubst %, docker-push-%,$(SUBIMAGES))

.PHONY: manifest-create
manifest-create:
	@echo "creating manifest $(IMAGE_NAME)"
	docker manifest create $(IMAGE_NAME) $(foreach arch,$(SUBIMAGES), --amend $(IMAGE_NAME)-$(arch))

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
