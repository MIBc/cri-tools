# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export GO111MODULE=off

GO ?= go
PROJECT := github.com/kubernetes-sigs/cri-tools
BINDIR := /usr/local/bin
ifeq ($(GOPATH),)
export GOPATH := $(CURDIR)/_output
unexport GOBIN
endif
GOBINDIR := $(word 1,$(subst :, ,$(GOPATH)))
PATH := $(GOBINDIR)/bin:$(PATH)
GOPKGDIR := $(GOPATH)/src/$(PROJECT)
GOPKGBASEDIR := $(shell dirname "$(GOPKGDIR)")

VERSION := $(shell git describe --tags --dirty --always)
VERSION := $(VERSION:v%=%)
GO_LDFLAGS := -X $(PROJECT)/pkg/version.Version=$(VERSION)

BUILD_PATH := $(shell pwd)/build
BUILD_BIN_PATH := $(BUILD_PATH)/bin

define go-build
	$(shell cd `pwd` && $(GO) build -o $(BUILD_BIN_PATH)/$(shell basename $(1)) $(1))
	@echo > /dev/null
endef

GINKGO := $(BUILD_BIN_PATH)/ginkgo
GOLANGCI_LINT := $(BUILD_BIN_PATH)/golangci-lint

all: binaries

help:
	@echo "Usage: make <target>"
	@echo
	@echo " * 'install' - Install binaries to system locations."
	@echo " * 'binaries' - Build critest and crictl."
	@echo " * 'clean' - Clean artifacts."

check-gopath:
ifeq ("$(wildcard $(GOPKGDIR))","")
	mkdir -p "$(GOPKGBASEDIR)"
	ln -s "$(CURDIR)" "$(GOPKGBASEDIR)/cri-tools"
endif
ifndef GOPATH
	$(error GOPATH is not set)
endif

critest: check-gopath
		CGO_ENABLED=0 $(GO) test -c \
		-ldflags '$(GO_LDFLAGS)' \
		$(PROJECT)/cmd/critest \
		-o $(GOBINDIR)/bin/critest

crictl: check-gopath
		CGO_ENABLED=0 $(GO) install \
		-ldflags '$(GO_LDFLAGS)' \
		$(PROJECT)/cmd/crictl

clean:
	find . -name \*~ -delete
	find . -name \#\* -delete

windows: check-gopath
	GOOS=windows $(GO) test -c -o $(CURDIR)/_output/critest.exe \
		-ldflags '$(GO_LDFLAGS)' \
		$(PROJECT)/cmd/critest
	GOOS=windows $(GO) build -o $(CURDIR)/_output/crictl.exe \
		-ldflags '$(GO_LDFLAGS)' \
		$(PROJECT)/cmd/crictl

binaries: critest crictl

install-critest: check-gopath
	install -D -m 755 $(GOBINDIR)/bin/critest $(BINDIR)/critest

install-crictl: check-gopath
	install -D -m 755 $(GOBINDIR)/bin/crictl $(BINDIR)/crictl

install: install-critest install-crictl

uninstall-critest:
	rm -f $(BINDIR)/critest

uninstall-crictl:
	rm -f $(BINDIR)/crictl

uninstall: uninstall-critest uninstall-crictl

lint: $(GOLANGCI_LINT)
	$(GOLANGCI_LINT) run
	./hack/repo-infra/verify/verify-boilerplate.sh

install.tools: $(GOLANGCI_LINT) $(GINKGO)

$(GOLANGCI_LINT):
	$(call go-build,./vendor/github.com/golangci/golangci-lint/cmd/golangci-lint)

$(GINKGO):
	$(call go-build,./vendor/github.com/onsi/ginkgo/ginkgo)

release:
	hack/release.sh

vendor:
	export GO111MODULE=on \
		$(GO) mod tidy && \
		$(GO) mod vendor && \
		$(GO) mod verify

.PHONY: \
	help \
	check-gopath \
	critest \
	crictl \
	clean \
	binaries \
	install \
	install-critest \
	install-crictl \
	uninstall \
	uninstall-critest \
	uninstall-crictl \
	lint \
	install.tools \
	release \
	vendor
