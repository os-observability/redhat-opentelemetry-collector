# RHOSDT OpenTelemetry Collector Distribution

This repository configures a build of the OpenTelemetry Collector with the supported components for a Red Hat OpenShift distributed tracing product.

## Update collector version

1. Update Makefile and manifest.yaml to select the desired upstream version and component selection for the product release. 
1. Run `make build` or `make build-in-podman`
1. Update changelog in [RPM spec](./opentelemetry-collector.spec.in)
1. Create a pull request with the changes, including changes in the `_build` directory.

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