%global goipath         github.com/os-observability/redhat-opentelemetry-collector

%define project_version %(make -s -C .. project_version)

Version:                %{project_version}
ExcludeArch:            %{ix86} s390 ppc ppc64 aarch64

%gometa

%global common_description %{expand:
Collector with the supported components for a Red Hat build of OpenTelemetry product}

%global golicenses    LICENSE
%global godocs        README.md

%define project_name %(make -s -C .. project_name)

Name:           %{project_name}
Release:        1%{?dist}
Summary:        Red Hat build of OpenTelemetry

License:        Apache-2.0

Source0:        %{name}-%{version}.tar.gz
Source1:        %{name}-deps-%{version}.tar.gz

BuildRequires: go-toolset-1.20
BuildRequires: git
BuildRequires: make

%description
%{common_description}

%prep
%goprep -k

%build
make build

%install
install -m 0755 -vd                     %{buildroot}%{_bindir}
install -m 0755 -vp %{gobuilddir}/bin/* %{buildroot}%{_bindir}/

%check
%gocheck

%files
%license %{golicenses}
%doc %{godocs}
%{_bindir}/*

%changelog
* Thu Feb 1 21:59:10 CET 2024 Nina Olear <nolear@redhat.com> - 0.93.4
- First package for Copr
