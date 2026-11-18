# Image de développement du labo OpenChoreo, linux/arm64. Aucun secret, aucun accès cluster, aucun identifiant monté.
# Base : digest de l'index multi-arch python:3.12-slim-bookworm (arm64 vérifié le 2026-11-18).
# Outils : version figée + sha256 de l'archive ou du binaire. Les empreintes de helm, yq, kubeconform, gitleaks et
# actionlint sont celles de .github/workflows/ci.yaml (même version). Toute montée = PR qui modifie ce fichier
# ET les empreintes de ci.yaml (tests/dev-factory/run.sh vérifie la concordance).
# Construction : tools/dev/dev up (ou docker build --platform linux/arm64 -f .devcontainer/Dockerfile .devcontainer).
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

# Paquets système figés (Debian bookworm arm64). git pour les worktrees, shasum (libdigest-sha-perl) pour les scripts
# tools/oke, flock pour sérialiser l'accès au cache partagé.
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
RUN set -eux; \
    curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/arm64/kubectl"; \
    echo "${KUBECTL_SHA256}  /usr/local/bin/kubectl" | sha256sum -c -; \
    chmod 0755 /usr/local/bin/kubectl

ARG HELM_VERSION=v4.1.3
ARG HELM_SHA256=5db45e027cc8de4677ec869e5d803fc7631b0bab1c1eb62ac603a62d22359a43
RUN set -eux; \
    cd /tmp; \
    curl -fsSLO "https://get.helm.sh/helm-${HELM_VERSION}-linux-arm64.tar.gz"; \
    echo "${HELM_SHA256}  helm-${HELM_VERSION}-linux-arm64.tar.gz" | sha256sum -c -; \
    tar -xzf "helm-${HELM_VERSION}-linux-arm64.tar.gz" -C /tmp linux-arm64/helm; \
    install -m 0755 /tmp/linux-arm64/helm /usr/local/bin/helm; \
    rm -rf /tmp/*

ARG KUBECONFORM_VERSION=0.7.0
ARG KUBECONFORM_SHA256=cc907ccf9e3c34523f0f32b69745265e0a6908ca85b92f41931d4537860eb83c
RUN set -eux; \
    cd /tmp; \
    curl -fsSLO "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-arm64.tar.gz"; \
    echo "${KUBECONFORM_SHA256}  kubeconform-linux-arm64.tar.gz" | sha256sum -c -; \
    tar -xzf kubeconform-linux-arm64.tar.gz -C /usr/local/bin kubeconform; \
    chmod 0755 /usr/local/bin/kubeconform; \
    rm -rf /tmp/*

ARG YQ_VERSION=4.50.1
ARG YQ_SHA256=cf0a663d8e4e00bb61507c5237b95b45a6aaa1fbedac77f4dc8abdadd5e2b745
RUN set -eux; \
    cd /tmp; \
    curl -fsSLo yq_linux_arm64 "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_arm64"; \
    echo "${YQ_SHA256}  yq_linux_arm64" | sha256sum -c -; \
    install -m 0755 yq_linux_arm64 /usr/local/bin/yq; \
    rm -rf /tmp/*

ARG GITLEAKS_VERSION=8.30.1
ARG GITLEAKS_SHA256=e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080
RUN set -eux; \
    cd /tmp; \
    curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_arm64.tar.gz"; \
    echo "${GITLEAKS_SHA256}  gitleaks_${GITLEAKS_VERSION}_linux_arm64.tar.gz" | sha256sum -c -; \
    tar -xzf "gitleaks_${GITLEAKS_VERSION}_linux_arm64.tar.gz" -C /usr/local/bin gitleaks; \
    chmod 0755 /usr/local/bin/gitleaks; \
    rm -rf /tmp/*

ARG ACTIONLINT_VERSION=1.7.12
ARG ACTIONLINT_SHA256=325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6
RUN set -eux; \
    cd /tmp; \
    curl -fsSLO "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_arm64.tar.gz"; \
    echo "${ACTIONLINT_SHA256}  actionlint_${ACTIONLINT_VERSION}_linux_arm64.tar.gz" | sha256sum -c -; \
    tar -xzf "actionlint_${ACTIONLINT_VERSION}_linux_arm64.tar.gz" -C /usr/local/bin actionlint; \
    chmod 0755 /usr/local/bin/actionlint; \
    rm -rf /tmp/*

ARG SHELLCHECK_VERSION=v0.11.0
ARG SHELLCHECK_SHA256=12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588
RUN set -eux; \
    cd /tmp; \
    curl -fsSLO "https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}/shellcheck-${SHELLCHECK_VERSION}.linux.aarch64.tar.xz"; \
    echo "${SHELLCHECK_SHA256}  shellcheck-${SHELLCHECK_VERSION}.linux.aarch64.tar.xz" | sha256sum -c -; \
    tar -xJf "shellcheck-${SHELLCHECK_VERSION}.linux.aarch64.tar.xz" -C /tmp; \
    find /tmp -type f -name shellcheck -exec install -m 0755 {} /usr/local/bin/shellcheck \; ; \
    rm -rf /tmp/*

ARG JQ_VERSION=jq-1.8.2
ARG JQ_SHA256=8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309
RUN set -eux; \
    cd /tmp; \
    curl -fsSLo jq-linux-arm64 "https://github.com/jqlang/jq/releases/download/${JQ_VERSION}/jq-linux-arm64"; \
    echo "${JQ_SHA256}  jq-linux-arm64" | sha256sum -c -; \
    install -m 0755 jq-linux-arm64 /usr/local/bin/jq; \
    rm -rf /tmp/*

ARG GH_VERSION=2.104.0
ARG GH_SHA256=cb34cefc6f4e77b90731374a2b737516bb8f3033c6ca46aa949e5344f68069e3
RUN set -eux; \
    cd /tmp; \
    curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_arm64.tar.gz"; \
    echo "${GH_SHA256}  gh_${GH_VERSION}_linux_arm64.tar.gz" | sha256sum -c -; \
    tar -xzf "gh_${GH_VERSION}_linux_arm64.tar.gz" -C /tmp; \
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
