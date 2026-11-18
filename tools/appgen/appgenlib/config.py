"""Chemins et constantes de politique d'appgen.

Role : source unique des chemins du depot et des constantes (noms OpenChoreo, tailles, quotas, egress, motifs
de secrets). Aucun calcul, aucune E/S.
Entrees : aucune (ROOT est deduit de l'emplacement du fichier).
Sorties : constantes importees par les autres modules ; `cli` lit PINS_PATH et PROJECT_PINS_PATH via ce module
(les tests peuvent donc les remplacer ici).
"""
from __future__ import annotations

import ipaddress
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCHEMA_PATH = ROOT / "docs" / "schema" / "app.schema.json"
CAPS_SCHEMA_PATH = ROOT / "docs" / "schema" / "capabilities.schema.json"
PINS_PATH = ROOT / "pins" / "resource-releases.yaml"
PROJECT_PINS_PATH = ROOT / "pins" / "project-releases.yaml"

# Annotations Argo exigees par APP-CONTRACT §5 (A1) : les finalizers de Component/Resource suppriment releases
# et objets rendus ; une ComponentRelease referencee ne doit jamais etre purgee ni supprimee.
SYNC_OPTIONS_KEY = "argocd.argoproj.io/sync-options"
SYNC_OPTIONS = {"Component": "Prune=false", "Resource": "Prune=false", "ComponentRelease": "Prune=false,Delete=false"}

# Marge de quota pour un RollingUpdate (A7) : le CCT ne fixe pas rollingUpdate.maxSurge, donc defaut Kubernetes
# 25 % arrondi au superieur (au moins 1 pod). Recreate, CronJob (concurrencyPolicy Forbid) : aucun surplus.
MAX_SURGE_PERCENT = 25

NS = "default"
PIPELINE = "standard"
PROJECT_TYPE = "cell-restricted"
COMPONENT_TYPE = "deployment/service-restricted"
CCT_NAME = "service-restricted"
PVC_TRAIT = "persistent-volume-claim"
CRT_NAME = "cnpg-lab-db"
DB_INSTANCE = "lab-pg"
ALLOWED_ENVIRONMENTS = {"development", "production"}
# Placement par defaut (ADR-0003 §4, decision de Paul du 2026-11-18) : une app va sur le homelab ; oke seulement
# sur demande explicite de Paul.
DEFAULT_CLUSTER = "homelab"

# Type de composant par (kind, endpoint ?). Seul deployment/service-restricted existe dans platform/ aujourd'hui ;
# les autres sont a livrer par platform/ (APP-CONTRACT section 7.4). Absent => render echoue (jamais de repli).
CCT_BY_KIND = {
    ("Deployment", True): "deployment/service-restricted",
    ("Deployment", False): "deployment/worker-restricted",
    ("StatefulSet", True): "statefulset/statefulset-restricted",
    ("StatefulSet", False): "statefulset/statefulset-restricted",
    ("CronJob", False): "cronjob/cronjob-restricted",
}
ROOT_EXCEPTION_CCT = "deployment/service-root-exception"
PVC_TRAIT_BY_KIND = {"Deployment": PVC_TRAIT, "StatefulSet": "persistent-volume-claim-sts"}
ACCESS_MODE = {"block-rwo": "ReadWriteOnce", "rwx-shared": "ReadWriteMany"}
# Parametres du ClusterProjectType ajoutes par les extensions (a declarer par platform/ avant usage).
CPT_EXT_PARAMS = ("egressCIDRs", "egressFQDNs", "egressApps", "databaseNamespace", "databaseCluster", "podSecurity")

# Requests par taille (table kube-ops, identique a la CCT) et quota de cellule par defaut (CPT).
SIZE_REQUESTS = {"small": (50, 128), "medium": (200, 256)}
QUOTA_DEFAULT = (300, 512)
QUOTA_MAX = (1000, 2048)   # au-dela : refus (E11 non livre)

# Egress (E3).
PRIVATE_NETS = [ipaddress.ip_network(c) for c in
                ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10", "169.254.0.0/16")]
LINK_LOCAL = ipaddress.ip_network("169.254.0.0/16")
NON_ROUTABLE = [ipaddress.ip_network(c) for c in ("0.0.0.0/8", "127.0.0.0/8", "224.0.0.0/4", "240.0.0.0/4")]
MIN_PUBLIC_PREFIX = 8
FORBIDDEN_FQDN_SUFFIXES = (".local", ".localhost", ".internal", ".svc", ".cluster.local", ".arpa", ".lan", ".home")
FORBIDDEN_FQDN_PREFIXES = ("metadata.", "instance-data.")

# Exceptions (E12).
MAX_EXCEPTION_DAYS = 90

# Parcours Helm (Argo CD). URL du depot GitOps = $id du schema [S : a confirmer au premier push].
GITOPS_REPO = "https://github.com/platform-zephyr/openchoreo-lab.git"
GITOPS_REVISION = "main"
ARGO_NAMESPACE = "argocd"
ARGO_PROJECT_HELM = "lab-helm"

# Valeurs interdites ou dangereuses, cherchees dans toutes les cles et valeurs de app.yaml.
FORBIDDEN_TOKENS = ("LoadBalancer", "NodePort", "hostPath", "hostNetwork", "privileged", "ClusterRoleBinding")
SECRET_LIKE_ENV = re.compile(r"(PASSWORD|PASSWD|SECRET|TOKEN|PRIVATE_KEY|API_KEY|CREDENTIAL|ACCESS_KEY)")
SECRET_LIKE_VALUE = [
    re.compile(r"-----BEGIN "),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{30,}"),
    re.compile(r"sk-[A-Za-z0-9]{20,}"),
    re.compile(r"[a-z][a-z0-9+.-]*://[^/\s:@]+:[^/\s@]+@"),  # URL avec identifiants
]
REF_OK = re.compile(r"^[a-z][a-z0-9-]{1,18}[a-z0-9]$")
