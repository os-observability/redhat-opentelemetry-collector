# RHOSDT OpenTelemetry Collector Configuration

This repository configures a build of the OpenTelemetry Collector with the supported components for a Red Hat OpenShift distributed tracing product release.

## Updating and Testing

1. Update Makefile and manifest.yaml to select the desired upstream version and component selection for the product release. 
1. If the component selection has changed, update test-config.yaml to configure all supported extensions, receivers, processors, and exporters, and to include these in the service pipeline. 
1. Run `make build`
1. Run `./_build/otelcol --config test-config.yaml` and make sure that otelcol starts without any errors or warnings, then kill it.
1. Create a pull request with the changes, including changes in the _build directory.
1. After the PR has merged, tag the repository with the product version referenced by the CpaaS build system.
