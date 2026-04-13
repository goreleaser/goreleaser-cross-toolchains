include .env
export

.PHONY: release-dryrun
release-dryrun:
	goreleaser release -f .goreleaser.yaml --clean --parallelism=1 --skip=publish,validate --snapshot

.PHONY: release
release:
	goreleaser release -f .goreleaser.yaml --clean --parallelism=1
