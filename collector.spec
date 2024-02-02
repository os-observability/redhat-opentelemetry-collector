%global goipath         github.com/os-observability/redhat-opentelemetry-collector

Version:                0.92.0
ExcludeArch:            %{ix86} s390 ppc ppc64 aarch64

%gometa

%global common_description %{expand:
Collector with the supported components for a Red Hat build of OpenTelemetry product}

%global golicenses    LICENSE
%global godocs        README.md

Name:           redhat-opentelemetry-collector
Release:        1%{?dist}
Summary:        Red Hat build of OpenTelemetry
```

License:        Apache-2.0

Source0:        %{name}-%{version}.tar.gz
Source1:        %{name}-deps-%{version}.tar.gz

BuildRequires: go-toolset-1.20
BuildRequires: git

%description
%{common_description}

%gopkg

%prep
%goprep

%build
make build

%install
%gopkginstall
install -m 0755 -vd                     %{buildroot}%{_bindir}
install -m 0755 -vp %{gobuilddir}/bin/* %{buildroot}%{_bindir}/

%check
%gocheck

%files
%license %{golicenses}
%doc %{godocs}
%{_bindir}/*

%gopkgfiles

%changelog
* Thu Feb 1 21:59:10 CET 2024 Nina Olear <nolear@redhat.com> - 0.93.4
- First package for Copr