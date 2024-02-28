#!/usr/bin/make -f

srpm:
	# Setup development environment
	dnf install -y git make curl gzip tar rpm-build golang fedpkg which

	# Generate SRPM
	make -C .. rpm/source RPM_BUILDER=fedpkg RELEASE=epel7

	if [[ "${outdir}" != "" ]]; then \
		mv dist/*.src.rpm ${outdir}/; \
	fi
