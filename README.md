# RHOSDT OpenTelemetry Collector Distribution

This repository configures a build of the OpenTelemetry Collector with the supported components for a Red Hat OpenShift distributed tracing product.

## Update collector version

1. Update Makefile and manifest.yaml to select the desired upstream version and component selection for the product release. 
1. Run `make build` or `make build-in-podman`
1. Create a pull request with the changes, including changes in the `_build` directory.
1. Update changelog in [RPM spec](./opentelemetry-collector.spec.in)

## Release

1. Verify the support levels for each component using the [component parser](./component-parser/README.md). Check with the team for those components whose support level has changed.
    * If a component is not supported anymore and our support level is `Tech Preview`: mention it to the team, add a new entry to the release notes and remove it from the `manifest.yaml` file.
    * If a component is not supported anymore and our support level is `General Availability`: mention it to the team to decide how to proceed.
2. Tag the release commit and push the tag to origin:
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
