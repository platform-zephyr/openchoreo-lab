# Image de développement du labo OpenChoreo, linux/amd64 et linux/arm64 (ARG TARGETARCH, posé par BuildKit). Aucun secret, aucun accès cluster, aucun identifiant monté.
# Base : digest de l'index multi-arch python:3.12-slim-bookworm (l'architecture est résolue par l'index).
# Outils : version figée + sha256 de l'archive ou du binaire PAR architecture, copiés de tools/dev/toolchain.lock
# (<OUTIL>_SHA256 = linux-arm64, <OUTIL>_AMD64_SHA256 = linux-amd64). Les empreintes arm64 de helm, yq, kubeconform,
# gitleaks et actionlint sont celles de .github/workflows/ci.yaml (même version). Toute montée = PR qui modifie le lock,
# ce fichier ET ci.yaml (tests/dev-factory/lock-concordance.sh vérifie la concordance, sans réseau).
# Un ARG *_AMD64_SHA256 vide signifie « empreinte absente du lock » : le build amd64 de cet outil s'arrête (BLOCKED),
# aucune empreinte n'est inventée ; la passer explicitement par --build-arg ne la fait entrer dans aucune preuve.
# Construction : tools/dev/dev up, ou docker buildx build --platform linux/<arch> -f .devcontainer/Dockerfile .devcontainer
# (sans --platform : architecture de l'hôte).
FROM python:3.12-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df

ENV DEBIAN_FRONTEND=noninteractive \
    DEV_FACTORY=1 \
    HOME=/home/dev \
    XDG_CACHE_HOME=/home/dev/.cache \
    PIP_CACHE_DIR=/home/dev/.cache/pip \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HELM_CACHE_HOME=/home/dev/.cache/helm \
    OKE_PHASEB_STATE=/home/dev/.cache/openchoreo-lab-phaseb \
    PATH=/opt/lint/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

# Posé par BuildKit (amd64 ou arm64) ; vide avec l'ancien constructeur : les RUN d'outils refusent alors de construire.
ARG TARGETARCH

# Paquets système figés (Debian bookworm, mêmes versions en amd64 et arm64). git pour les worktrees, shasum
# (libdigest-sha-perl) pour les scripts tools/oke, flock pour sérialiser l'accès au cache partagé.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates=20230311+deb12u1 \
      curl=7.88.1-10+deb12u15 \
      xz-utils=5.4.1-1+deb12u1 \
      util-linux=2.38.1-5+deb12u3 \
      git=1:2.39.5-0+deb12u3 \
      libdigest-sha-perl=6.04-1; \
    rm -rf /var/lib/apt/lists/*

ARG KUBECTL_VERSION=v1.37.2
ARG KUBECTL_SHA256=fcc16f63186659d9722014b7e02d5fdd2d4e669cb8c0ab66365d7d3b8ba03509
ARG KUBECTL_AMD64_SHA256=
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) a=amd64; sha="${KUBECTL_AMD64_SHA256}" ;; \
      arm64) a=arm64; sha="${KUBECTL_SHA256}" ;; \
      *) echo "TARGETARCH non pris en charge : '${TARGETARCH}'" >&2; exit 1 ;; \
    esac; \
    [ -n "$sha" ] || { echo "BLOCKED: KUBECTL_AMD64_SHA256 absente de tools/dev/toolchain.lock (T-454)" >&2; exit 1; }; \
    curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${a}/kubectl"; \
    echo "${sha}  /usr/local/bin/kubectl" | sha256sum -c -; \
    chmod 0755 /usr/local/bin/kubectl

ARG HELM_VERSION=v4.1.3
ARG HELM_SHA256=5db45e027cc8de4677ec869e5d803fc7631b0bab1c1eb62ac603a62d22359a43
ARG HELM_AMD64_SHA256=02ce9722d541238f81459938b84cf47df2fdf1187493b4bfb2346754d82a4700
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) a=amd64; sha="${HELM_AMD64_SHA256}" ;; \
      arm64) a=arm64; sha="${HELM_SHA256}" ;; \
      *) echo "TARGETARCH non pris en charge : '${TARGETARCH}'" >&2; exit 1 ;; \
    esac; \
    [ -n "$sha" ] || { echo "BLOCKED: HELM_AMD64_SHA256 absente de tools/dev/toolchain.lock (T-454)" >&2; exit 1; }; \
    cd /tmp; \
    f="helm-${HELM_VERSION}-linux-${a}.tar.gz"; \
    curl -fsSLO "https://get.helm.sh/${f}"; \
    echo "${sha}  ${f}" | sha256sum -c -; \
    tar -xzf "${f}" -C /tmp "linux-${a}/helm"; \
    install -m 0755 "/tmp/linux-${a}/helm" /usr/local/bin/helm; \
    rm -rf /tmp/*

ARG KUBECONFORM_VERSION=0.7.0
ARG KUBECONFORM_SHA256=cc907ccf9e3c34523f0f32b69745265e0a6908ca85b92f41931d4537860eb83c
ARG KUBECONFORM_AMD64_SHA256=c31518ddd122663b3f3aa874cfe8178cb0988de944f29c74a0b9260920d115d3
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) a=amd64; sha="${KUBECONFORM_AMD64_SHA256}" ;; \
      arm64) a=arm64; sha="${KUBECONFORM_SHA256}" ;; \
      *) echo "TARGETARCH non pris en charge : '${TARGETARCH}'" >&2; exit 1 ;; \
    esac; \
    [ -n "$sha" ] || { echo "BLOCKED: KUBECONFORM_AMD64_SHA256 absente de tools/dev/toolchain.lock (T-454)" >&2; exit 1; }; \
    cd /tmp; \
    f="kubeconform-linux-${a}.tar.gz"; \
    curl -fsSLO "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/${f}"; \
    echo "${sha}  ${f}" | sha256sum -c -; \
    tar -xzf "${f}" -C /usr/local/bin kubeconform; \
    chmod 0755 /usr/local/bin/kubeconform; \
    rm -rf /tmp/*

ARG YQ_VERSION=4.50.1
ARG YQ_SHA256=cf0a663d8e4e00bb61507c5237b95b45a6aaa1fbedac77f4dc8abdadd5e2b745
ARG YQ_AMD64_SHA256=c7a1278e6bbc4924f41b56db838086c39d13ee25dcb22089e7fbf16ac901f0d4
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) a=amd64; sha="${YQ_AMD64_SHA256}" ;; \
      arm64) a=arm64; sha="${YQ_SHA256}" ;; \
      *) echo "TARGETARCH non pris en charge : '${TARGETARCH}'" >&2; exit 1 ;; \
    esac; \
    [ -n "$sha" ] || { echo "BLOCKED: YQ_AMD64_SHA256 absente de tools/dev/toolchain.lock (T-454)" >&2; exit 1; }; \
    cd /tmp; \
    f="yq_linux_${a}"; \
    curl -fsSLo "${f}" "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/${f}"; \
    echo "${sha}  ${f}" | sha256sum -c -; \
    install -m 0755 "${f}" /usr/local/bin/yq; \
    rm -rf /tmp/*

ARG GITLEAKS_VERSION=8.30.1
ARG GITLEAKS_SHA256=e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080
ARG GITLEAKS_AMD64_SHA256=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) a=x64; sha="${GITLEAKS_AMD64_SHA256}" ;; \
      arm64) a=arm64; sha="${GITLEAKS_SHA256}" ;; \
      *) echo "TARGETARCH non pris en charge : '${TARGETARCH}'" >&2; exit 1 ;; \
    esac; \
    [ -n "$sha" ] || { echo "BLOCKED: GITLEAKS_AMD64_SHA256 absente de tools/dev/toolchain.lock (T-454)" >&2; exit 1; }; \
    cd /tmp; \
    f="gitleaks_${GITLEAKS_VERSION}_linux_${a}.tar.gz"; \
    curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${f}"; \
    echo "${sha}  ${f}" | sha256sum -c -; \
    tar -xzf "${f}" -C /usr/local/bin gitleaks; \
    chmod 0755 /usr/local/bin/gitleaks; \
    rm -rf /tmp/*

ARG ACTIONLINT_VERSION=1.7.12
ARG ACTIONLINT_SHA256=325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6
ARG ACTIONLINT_AMD64_SHA256=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) a=amd64; sha="${ACTIONLINT_AMD64_SHA256}" ;; \
      arm64) a=arm64; sha="${ACTIONLINT_SHA256}" ;; \
      *) echo "TARGETARCH non pris en charge : '${TARGETARCH}'" >&2; exit 1 ;; \
    esac; \
    [ -n "$sha" ] || { echo "BLOCKED: ACTIONLINT_AMD64_SHA256 absente de tools/dev/toolchain.lock (T-454)" >&2; exit 1; }; \
    cd /tmp; \
    f="actionlint_${ACTIONLINT_VERSION}_linux_${a}.tar.gz"; \
    curl -fsSLO "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${f}"; \
    echo "${sha}  ${f}" | sha256sum -c -; \
    tar -xzf "${f}" -C /usr/local/bin actionlint; \
    chmod 0755 /usr/local/bin/actionlint; \
    rm -rf /tmp/*

ARG SHELLCHECK_VERSION=v0.11.0
ARG SHELLCHECK_SHA256=12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588
ARG SHELLCHECK_AMD64_SHA256=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) a=x86_64; sha="${SHELLCHECK_AMD64_SHA256}" ;; \
      arm64) a=aarch64; sha="${SHELLCHECK_SHA256}" ;; \
      *) echo "TARGETARCH non pris en charge : '${TARGETARCH}'" >&2; exit 1 ;; \
    esac; \
    [ -n "$sha" ] || { echo "BLOCKED: SHELLCHECK_AMD64_SHA256 absente de tools/dev/toolchain.lock (T-454)" >&2; exit 1; }; \
    cd /tmp; \
    f="shellcheck-${SHELLCHECK_VERSION}.linux.${a}.tar.xz"; \
    curl -fsSLO "https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}/${f}"; \
    echo "${sha}  ${f}" | sha256sum -c -; \
    tar -xJf "${f}" -C /tmp; \
    find /tmp -type f -name shellcheck -exec install -m 0755 {} /usr/local/bin/shellcheck \; ; \
    rm -rf /tmp/*

ARG JQ_VERSION=jq-1.8.2
ARG JQ_SHA256=8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309
ARG JQ_AMD64_SHA256=
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) a=amd64; sha="${JQ_AMD64_SHA256}" ;; \
      arm64) a=arm64; sha="${JQ_SHA256}" ;; \
      *) echo "TARGETARCH non pris en charge : '${TARGETARCH}'" >&2; exit 1 ;; \
    esac; \
    [ -n "$sha" ] || { echo "BLOCKED: JQ_AMD64_SHA256 absente de tools/dev/toolchain.lock (T-454)" >&2; exit 1; }; \
    cd /tmp; \
    f="jq-linux-${a}"; \
    curl -fsSLo "${f}" "https://github.com/jqlang/jq/releases/download/${JQ_VERSION}/${f}"; \
    echo "${sha}  ${f}" | sha256sum -c -; \
    install -m 0755 "${f}" /usr/local/bin/jq; \
    rm -rf /tmp/*

ARG GH_VERSION=2.104.0
ARG GH_SHA256=cb34cefc6f4e77b90731374a2b737516bb8f3033c6ca46aa949e5344f68069e3
ARG GH_AMD64_SHA256=
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) a=amd64; sha="${GH_AMD64_SHA256}" ;; \
      arm64) a=arm64; sha="${GH_SHA256}" ;; \
      *) echo "TARGETARCH non pris en charge : '${TARGETARCH}'" >&2; exit 1 ;; \
    esac; \
    [ -n "$sha" ] || { echo "BLOCKED: GH_AMD64_SHA256 absente de tools/dev/toolchain.lock (T-454)" >&2; exit 1; }; \
    cd /tmp; \
    f="gh_${GH_VERSION}_linux_${a}.tar.gz"; \
    curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${f}"; \
    echo "${sha}  ${f}" | sha256sum -c -; \
    tar -xzf "${f}" -C /tmp; \
    find /tmp -type f -name gh -path '*/bin/*' -exec install -m 0755 {} /usr/local/bin/gh \; ; \
    rm -rf /tmp/*

# Outils Python de lint, dans un venv root non modifiable par l'utilisateur (versions = CI et tools/appgen/requirements.txt).
RUN set -eux; \
    python -m venv /opt/lint; \
    /opt/lint/bin/pip install --no-cache-dir "yamllint==1.38.0" "PyYAML==6.0.2" "jsonschema==4.23.0"

# Utilisateur non-root dont l'UID/GID = ceux de l'hôte (fichiers du worktree lisibles et écrivables sans root).
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN set -eux; \
    groupadd -o -g "${HOST_GID}" dev; \
    useradd -o -m -u "${HOST_UID}" -g "${HOST_GID}" -s /bin/bash dev; \
    install -d -o "${HOST_UID}" -g "${HOST_GID}" /home/dev/.cache/pip /home/dev/.cache/helm /home/dev/.cache/openchoreo-lab-phaseb /workspaces/openchoreo-lab

USER dev
WORKDIR /workspaces/openchoreo-lab
CMD ["sleep", "infinity"]
