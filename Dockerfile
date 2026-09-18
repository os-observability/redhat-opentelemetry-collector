FROM registry.redhat.io/ubi9/ubi-minimal as bpf-generator

WORKDIR /opt/app-root/src
USER root

RUN microdnf -y install golang clang llvm make && \
    microdnf clean all && \
    rm -rf /var/cache/yum

COPY .obi-src .obi-src
RUN make -C .obi-src generate

FROM registry.redhat.io/ubi9/ubi-minimal as builder

WORKDIR /opt/app-root/src
USER root

RUN microdnf -y install which golang make
COPY . .
COPY --from=bpf-generator /opt/app-root/src/.obi-src .obi-src

RUN CGO_ENABLED=0 go build -C ./_build -mod=mod -o opentelemetry-collector -trimpath -ldflags "-w"

FROM registry.redhat.io/ubi9/ubi-micro AS target-base

FROM registry.redhat.io/ubi9/ubi as install-additional-packages
COPY --from=target-base / /mnt/rootfs
RUN rpm --root /mnt/rootfs --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
# Install the systemd package which provides journalctl required by journald receiver and add user to systemd-journal group.
# https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/journaldreceiver
RUN dnf install --installroot /mnt/rootfs --releasever 9 --setopt install_weak_deps=false --setopt reposdir=/etc/yum.repos.d --nodocs -y systemd && \
    dnf clean all && \
    rm -rf /mnt/rootfs/var/cache/*

FROM scratch
WORKDIR /
COPY --from=install-additional-packages /mnt/rootfs/ /

COPY --from=builder /opt/app-root/src/_build/opentelemetry-collector /usr/bin/opentelemetry-collector
COPY configs/otelcol.yaml /etc/otelcol/config.yaml

ARG USER_UID=1001
RUN useradd -u ${USER_UID} otelcol && usermod -a -G systemd-journal otelcol
USER ${USER_UID}
ENTRYPOINT ["/usr/bin/opentelemetry-collector"]
CMD ["--config", "/etc/otelcol/config.yaml"]
EXPOSE 4317 55678 55679

LABEL com.redhat.component="opentelemetry-collector-container" \
      name="rhosdt/opentelemetry-collector-rhel9" \
      summary="OpenTelemetry Collector" \
      description="Collector for the distributed tracing system" \
      io.k8s.description="Collector for the distributed tracing system." \
      io.openshift.expose-services="4317:otlp,9411:zipkin" \
      io.openshift.tags="tracing" \
      io.k8s.display-name="OpenTelemetry Collector"