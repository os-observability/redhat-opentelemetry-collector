# RHOSDT OpenTelemetry Collector Distribution

This repository configures a build of the OpenTelemetry Collector with the supported components for a Red Hat OpenShift distributed tracing product.

## Update collector version

1. Update Makefile and manifest.yaml to select the desired upstream version and component selection for the product release. 
1. Run `make build generate-schemas` or `make build-in-podman`
1. Update changelog in [RPM spec](./opentelemetry-collector.spec.in)
1. Create a pull request with the changes, including changes in the `_build` directory.

## Update OBI version

The OpenTelemetry eBPF Instrumentation (OBI) receiver is pinned in two places
that must be kept in sync:

- **`manifest.yaml`** declares the module version, e.g. `go.opentelemetry.io/obi v0.10.0`.
- **`.obi-src`** is a git submodule (see [`.gitmodules`](./.gitmodules)) pinned to a
  specific commit. A `replace` directive in `manifest.yaml`
  (`go.opentelemetry.io/obi => ../.obi-src`) redirects the module to this local
  checkout, so the submodule commit is what actually gets built. The eBPF
  artifacts are generated from it by `make generate-obi`.

To bump to a new OBI release (e.g. `v0.11.0`):

1. Move the submodule to the matching upstream tag or commit:
   ```
   git -C .obi-src fetch --tags
   git -C .obi-src checkout v0.11.0
   git add .obi-src
   ```
1. Update the module version string in [`manifest.yaml`](./manifest.yaml) to match
   (`go.opentelemetry.io/obi v0.11.0`).
1. Run `make build generate-schemas` or `make build-in-podman`. This regenerates the
   OBI eBPF artifacts and the contents of the `_build` directory.
1. Create a pull request with the changes, including the updated submodule pointer,
   `manifest.yaml`, and the `_build` directory.

## Release

```
git tag v0.48.0 && git push origin v0.48.0
```

## RPM

To build `srpm` and `rpm`s we used [packit](https://packit.dev/).

```
# build srpm 
make clean packit/srpm

# build rpm (includes srpm)
make clean packit/rpm/mock
```

## Install from Copr

```
dnf copr enable frzifus/redhat-opentelemetry-collector-main 
dnf install -y opentelemetry-collector
```

## Tests

The end-to-end tests are located at [openshift/distributed-tracing-qe/tests/e2e-otel](https://github.com/openshift/distributed-tracing-qe/tree/main/tests/e2e-otel).