GO=$(shell which go)
OTELCOL_BUILDER_VERSION ?= 0.92.0
OTELCOL_BUILDER_DIR ?= ${PWD}/bin
OTELCOL_BUILDER ?= ${OTELCOL_BUILDER_DIR}/ocb

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
	curl -sLo $(OTELCOL_BUILDER) "https://github.com/open-telemetry/opentelemetry-collector/releases/download/cmd%2Fbuilder%2Fv$(OTELCOL_BUILDER_VERSION)/ocb_$(OTELCOL_BUILDER_VERSION)_$${os}_$${machine}" ;\
	chmod +x $(OTELCOL_BUILDER) ;\
	}
else
OTELCOL_BUILDER=$(shell which ocb)
endif
