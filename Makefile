GO=$(shell which go)
OTELCOL_VERSION ?= 0.95.0
# TODO: Align the ocb version with the collector version as soon as the ubi go 1.21 is supported.
OCB_VERSION ?= 0.93.0
OTELCOL_BUILDER_DIR ?= ${PWD}/bin
OTELCOL_BUILDER ?= ${OTELCOL_BUILDER_DIR}/ocb
PROJECT ?= redhat-opentelemetry-collector
RPM_BUILDER ?= fedpkg 
RELEASE ?= epel7

build: ocb
	mkdir -p _build
	${OTELCOL_BUILDER} --skip-compilation=false --go ${GO} --config manifest.yaml 2>&1 | tee _build/build.log

generate-sources: ocb
	@mkdir -p _build
	${OTELCOL_BUILDER} --skip-compilation=true --go ${GO} --config manifest.yaml 2>&1 | tee _build/build.log

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
	curl -sLo $(OTELCOL_BUILDER) "https://github.com/open-telemetry/opentelemetry-collector/releases/download/cmd%2Fbuilder%2Fv$(OCB_VERSION)/ocb_$(OCB_VERSION)_$${os}_$${machine}" ;\
	chmod +x $(OTELCOL_BUILDER) ;\
	}
else
OTELCOL_BUILDER=$(shell which ocb)
endif

# Download all dependencies to the vendor directory.
.PHONY: vendor
vendor:
	@echo "Downloading dependencies of the custom collector..."
	cd ./_build && $(GO) mod tidy && $(GO) mod vendor

# Archive the source code with all dependencies in a tarball.
.PHONY: archive
archive: vendor
	mkdir -p dist/

	@echo "Creating a tarball with the source code..."
	git archive \
	--prefix=$(PROJECT)-$(OTELCOL_VERSION)/ \
	--output ./dist/$(PROJECT)-$(OTELCOL_VERSION).tar.gz \
	HEAD

	@echo "Creating a tarball with dependencies..."
	tar -cz \
	--transform="s/^\./$(PROJECT)-$(OTELCOL_VERSION)/" \
	--file ./dist/$(PROJECT)-deps-$(OTELCOL_VERSION).tar.gz \
	./_build/vendor

	@echo "The archives are available at dist/:"
	@find dist/*.tar.gz

# Build the collector as RPM.
.PHONY: rpm/source
rpm/source: collector.spec archive
	cp *.spec ./dist && cd dist/ && $(RPM_BUILDER) --release "$(RELEASE)" srpm

.PHONY: collector.spec
collector.spec: collector.spec.in
	sed -e "s/%%PROJECT%%/$(PROJECT)/" -e "s/%%VERSION%%/$(OTELCOL_VERSION)/" < $< > $@

rpm/fedora-testbuild:
	docker run --rm -v ${PWD}:/src:z fedora:39 /bin/bash -c 'dnf install -y git make && git config --global --add safe.directory /src && pushd src && export GOPROXY=https://proxy.golang.org,direct && make -C .copr srpm && popd'
