GO ?= $(shell which go)
OCB_VERSION ?= 0.127.0
OTELCOL_VERSION = $(OCB_VERSION)
OTELCOL_BUILDER_DIR ?= ${PWD}/bin
OTELCOL_BUILDER ?= ${OTELCOL_BUILDER_DIR}/ocb
PROJECT ?= opentelemetry-collector
RPM_BUILDER ?= fedpkg 
RELEASE ?= epel7
MAKEFLAGS += --silent

build: ocb
	mkdir -p _build
	DIST_GO=${GO} ${OTELCOL_BUILDER} --skip-compilation=false --config manifest.yaml 2>&1 | tee _build/build.log

build-in-podman:
	podman run -v $$PWD:/app -w /app --security-opt label=disable registry.access.redhat.com/ubi9/ubi-minimal \
	  /bin/sh -c "microdnf -y install make which golang && make build"

generate-sources: ocb
	@mkdir -p _build
	DIST_GO=${GO} ${OTELCOL_BUILDER} --skip-compilation=true --config manifest.yaml 2>&1 | tee _build/build.log

ocb:
ifeq (, $(shell which ocb >/dev/null 2>/dev/null))
	@{ \
	set -e ;\
	os=$$(uname | tr A-Z a-z) ;\
	machine=$$(uname -m) ;\
	[ "$${machine}" != x86 ] || machine=386 ;\
	[ "$${machine}" != x86_64 ] || machine=amd64 ;\
	echo "Installing ocb ($${os}/$${machine}) at $(OTELCOL_BUILDER_DIR)";\
	mkdir -p $(OTELCOL_BUILDER_DIR) ;\
	curl -sLo $(OTELCOL_BUILDER) "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/cmd%2Fbuilder%2Fv$(OCB_VERSION)/ocb_$(OCB_VERSION)_$${os}_$${machine}" ;\
	chmod +x $(OTELCOL_BUILDER) ;\
	}
else
OTELCOL_BUILDER=$(shell which ocb)
endif

# Download all dependencies to the vendor directory.
.PHONY: vendor
vendor:
	@echo "Downloading dependencies of the custom collector..."
	cd ./_build && GOPROXY='https://proxy.golang.org,direct' $(GO) mod tidy && $(GO) mod vendor

# Archive the source code with all dependencies in a tarball.
.PHONY: archive
archive: vendor
	mkdir -p dist/
	# NOTE: we copy README and LICENSE into _build, since append does not work on a tar.gz.
	cp README.md _build
	cp LICENSE _build
	cp otel_collector_journald.te _build
	cp opentelemetry-collector-with-options 00-default-receivers.yaml opentelemetry-collector.service _build

	@echo "Creating a tarball with the source code & dependencies..."
	tar -cz \
	--transform="s/^\./redhat-$(PROJECT)-$(OTELCOL_VERSION)/" \
	--file ./dist/$(PROJECT)-$(OTELCOL_VERSION).tar.gz \
	-C ./_build .

	@echo "The archives are available at dist/:"
	@find dist/*.tar.gz

.PHONY: pkg/selinux
pkg/selinux:
	checkmodule -M -m -o otel_collector_journald.mod otel_collector_journald.te
	semodule_package -o otel_collector_journald.pp -m otel_collector_journald.mod

# Build the collector as RPM.
.PHONY: rpm/source
rpm/source: opentelemetry-collector.spec archive
	cp *.spec ./dist && cd dist/ && $(RPM_BUILDER) --release "$(RELEASE)" srpm

.PHONY: opentelemetry-collector.spec
opentelemetry-collector.spec: opentelemetry-collector.spec.in
	sed -e "s/%%PROJECT%%/$(PROJECT)/" -e "s/%%VERSION%%/$(OTELCOL_VERSION)/" < $< > $@

.PHONY: rpm/fedora-testbuild
rpm/fedora-testbuild:
	docker run --rm -v ${PWD}:/src:z fedora:39 /bin/bash -c 'dnf install -y git make && git config --global --add safe.directory /src && pushd src && export GOPROXY=https://proxy.golang.org,direct && make -C .copr srpm && popd'

.PHONY: version
version:
	@echo $(OTELCOL_VERSION)

.PHONY: packit/srpm
packit/srpm:
	packit --debug srpm

.PHONY: packit/srpm
packit/rpm/mock:
	packit build in-mock

.PHONY: clean
clean:
	rm -rf ./dist ./_build/vendor ./bin
	rm -rf opentelemetry-collector.spec
	rm -rf *.tar.gz *.rpm
