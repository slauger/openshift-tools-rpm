SHELL := /bin/bash
ARCH := x86_64
ROOT_DIR := $(CURDIR)
REPO_DIR := $(CURDIR)/repo
PACKAGES := helm oc kubectl yq kubectx argocd tkn virtctl trivy conftest velero stern k9s kustomize kn cosign kubeseal

.PHONY: all clean repo download build pkg

all: download build repo

download:
	@for pkg in $(PACKAGES); do \
		$(ROOT_DIR)/scripts/download.sh $$pkg; \
	done

build:
	@for pkg in $(PACKAGES); do \
		VERSION=$$(yq ".packages.$${pkg}.version" $(ROOT_DIR)/versions.yaml); \
		echo "==> Building $${pkg} $${VERSION}"; \
		cd $(ROOT_DIR)/packages/$${pkg} && \
		VERSION=$${VERSION} ARCH=$(ARCH) nfpm package --packager rpm --target . ; \
		cd $(ROOT_DIR); \
	done

repo:
	rm -rf $(REPO_DIR)
	mkdir -p $(REPO_DIR)
	find $(ROOT_DIR)/packages -name '*.rpm' -exec cp {} $(REPO_DIR)/ \;
	createrepo_c $(REPO_DIR)

clean:
	rm -rf $(REPO_DIR)
	find $(ROOT_DIR)/packages -name '*.rpm' -delete
	@for pkg in $(PACKAGES); do \
		rm -rf $(ROOT_DIR)/packages/$$pkg/bin; \
	done

# Build a single package: make pkg PKG=helm
pkg:
	$(ROOT_DIR)/scripts/download.sh $(PKG)
	@VERSION=$$(yq ".packages.$(PKG).version" $(ROOT_DIR)/versions.yaml); \
	cd $(ROOT_DIR)/packages/$(PKG) && \
	VERSION=$${VERSION} ARCH=$(ARCH) nfpm package --packager rpm --target .
