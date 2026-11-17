---
name: openchoreo-setup
description: Installer ou réinstaller OpenChoreo v1.3.3 pour le labo sur le cluster k3d local (Mac arm64, Colima profil openchoreo), avec un contexte kubectl explicite et un KUBECONFIG dédié, puis vérifier l'installation en lecture. Phase 0 seulement. L'installation sur OKE est hors de portée de l'agent (gate + MANDAT de Paul).
license: Apache-2.0 (adapté de openchoreo/skills@cefd81b, voir l'en-tête)
---

<!--
Adapted from openchoreo/skills@cefd81bc16b79bd2de0f6284e6fa06d6c15825b7:
skills/openchoreo-setup/SKILL.md et references/on-k3d-locally.md (Apache-2.0).
Modifications : cible unique k3d (cluster `openchoreo`), version figée v1.3.3 (pas de « latest »),
observability plane et workflow plane NON installés (budget, pas de build en cluster), Backstage et
event-forwarder désactivés, contexte et KUBECONFIG dédiés obligatoires, OKE exclu (gate) ;
fetch-page.sh non exécuté (la doc v1.3.x est lue) ; checklist de vérification adaptée ;
traduction en français.
-->

# Installation du labo (k3d uniquement)

Classe : AUTONOME sur k3d local (cluster jetable). **OKE : INTERDIT à l'agent** tant que le gate de `STATE.md` n'est pas franchi ; après le gate, c'est un MANDAT de Paul.

## 1. Choix figés (ne pas les reposer à l'utilisateur)

| Décision | Valeur labo |
|---|---|
| Version | OpenChoreo **v1.3.3**, charts épinglés ; dépendances : Gateway API v1.5.1, cert-manager v1.19.4, kgateway v2.3.11, ESO 2.0.1 (E-revue §4) |
| Plans | control plane + data plane seulement. Ni observability plane ni workflow plane |
| Valeurs | `backstage.enabled=false`, `eventForwarder.enabled=false`, requests baissées (budget ≤ 250m visé), MCP en lecture seule pour l'agent |
| Ressources par défaut | ne pas installer les types d'exemple pour les apps : `platform/` (CCT, CPT, CRT durcis) est appliqué par Argo |
| Runtime | Colima `colima start -p openchoreo --vm-type=vz --cpu 4 --memory 8`, `DOCKER_CONTEXT=colima-openchoreo`, `K3D_FIX_DNS=0` |

## 2. Contexte épinglé, toujours

```bash
export DOCKER_CONTEXT=colima-openchoreo
export KUBECONFIG="$SCRATCH/kc-openchoreo.yaml"          # fichier dédié, jamais ~/.kube/config de Paul
k3d kubeconfig write openchoreo --output "$KUBECONFIG"   # fichier local ; ne jamais l'afficher
kubectl --context k3d-openchoreo get nodes                # chaque commande nomme --context ; helm : --kube-context
```

Si `kubectl` répond par une erreur d'auth, `EOF` ou une API injoignable, c'est le mauvais contexte : résoudre le contexte avant d'aller plus loin, sans contourner.

## 3. Installer

Suivre la page « Run Locally on K3d » de la doc **v1.3.x** (openchoreo.dev/docs), de haut en bas, en sautant les sections des plans exclus et la partie « Try it out ». En cas d'échec : `describe`, `events`, logs, puis correction si elle reste dans le périmètre. Noter chaque écart pour le compte rendu ; ne retirer aucun `kubectl wait`.

## 4. Vérifier (lecture seule)

```bash
K="kubectl --context k3d-openchoreo"
$K get deploy -A | awk 'NR>1 && $4!=$5'                    # aucune ligne pour openchoreo-*, thunder, openbao
$K get crd | grep -c openchoreo.dev                        # CRD v1.3.3 présentes
$K get ns -l openchoreo.dev/project --show-labels | head   # cellules de démonstration éventuelles
$K top pods -A --no-headers 2>/dev/null | awk '$1 ~ /^openchoreo|^thunder/ {c+=$3; m+=$4} END {print "cpu(m)="c, "mem(Mi)="m}'
```

Critère : tout `Available` ; empreinte notée (budget OKE : ≤ 1,5 GiB et ≤ 0,3 vCPU au repos). Les résultats sont étiquetés `k3d`.

## 5. Compte rendu

Résultat (succès, partiel, échec), version, plans installés, valeurs modifiées, écarts par rapport à la doc, empreinte mesurée. Puis mise à jour de `STATE.md` par le coordinateur.

## Nettoyage

`k3d cluster delete openchoreo` (k3d seulement ; jamais une commande de destruction sur OKE).
