# Décisions ouvertes (architecture cible de l'IDP)

Statut : **à arbitrer par Paul**. Aucune n'est un prérequis du golden path `whoami` sur OKE.
Références : `TARGET-ARCHITECTURE.md` (TA), `MULTI-DATAPLANE.md` (MDP), `CATALOG-CONTRACT.md` (CC).

| # | Décision | Recommandation | Risques | Prouvé | Non prouvé |
|---|---|---|---|---|---|
| **D1** | Capacité OKE : **A** = séparation à 0 € (OKE = CP + identité seulement) ; **B** = second nœud A1 2 OCPU / 12 Go en PAYG + 100 Go de bloc | **B** si l'IDP doit remplacer l'implémentation actuelle ; A seulement pour prolonger l'expérimentation | A : 33/35 pods, aucune app sur OKE, restauration d'Authentik à 72 % CPU. B : ≈ 32 $/mois [E], fin du « Free Tier strict » (ADR OKE §3), quotas PLT-260 à lever | allocatable, kube-system, 150/200 Go pris, Always Free A1 = 2 OCPU / 12 Go | usage réel d'Argo, Authentik, OpenBao et Kyverno ; tarif PAYG du jour |
| **D2** | OpenBao : stockage et déscellement | backend **PostgreSQL** dans un CNPG « plateforme » partagé avec Authentik (1 volume) **si** la version épinglée le supporte ; sinon Raft sur un volume dédié. Auto-unseal hors cluster ; clés de récupération hors ligne | couplage de restauration Authentik ↔ OpenBao ; KMS OCI = même compte que le cluster (`docs/storage/OPENBAO-DOPPLER-ESO.md` §2) ; homelab-infra `secret-store-decision.md` déconseille OpenBao | rôle Doppler/OpenBao/ESO défini | backend PostgreSQL d'OpenBao ; exercice de restauration |
| **D3** | Kyverno sur OKE | **non en voie A** (PSA + VAP, conforme à l'ADR OKE l.42) ; **oui en voie B**, profil admission + background, `failurePolicy: Ignore` ou exclusion des namespaces de la plateforme | webhook `Fail` sur un nœud unique = restauration bloquée ; 2 pods de plus | VAP et PSA prouvées sur k3d (51 PASS) | matrice `KYVERNO-POLICY-CONTRACT.md` (pas encore écrite) |
| **D4** | Argo CD : un seul par cluster | **un seul** Argo OKE (celui de kube-ops `oracle-a1`) avec un AppProject `openchoreo-lab` restreint ; `lab-argocd` reste l'instance d'essai jusqu'à `whoami` | dépendance de gouvernance envers kube-ops (bootstrap appliqué par l'opérateur) ; deux Argo = 480 Mi et 4 pods en double | chart identique (10.3.3) | cohabitation sur OKE non testée |
| **D5** | Volumes de drill (2 × 50 Go, à Paul) | les **supprimer** après confirmation que les drills sont clos (D-2026-11-14-03) : c'est la condition de toute base sur OKE | perte d'une preuve de drill | volumes AVAILABLE, non attachés (OKE-AUDIT) | — |
| **D6** | Chemin réseau des agents Talos | **NetBird** vers `cluster-gateway-external:8443` seulement ; Cloudflare réseau privé en repli | ACL trop large ; SAN DNS à ajouter | mTLS de bout en bout exigé (MCC) | tout le chemin (MDP §7) |
| **D7** | Noms des Data Planes | garder `ClusterDataPlane default` pour `whoami` ; enregistrer Talos sous `talos` et renommer `default` → `oke` lors d'une fenêtre dédiée (Environment `production` à repointer) | renommer = recréer le CR et réenregistrer l'agent | — | effet d'un changement de `dataPlaneRef` sur les ReleaseBindings existants |
| **D8** | Catalogue fédéré | contrat CC ; activer la Location Helm **après** le correctif `appgen` (pas de `catalog-info.yaml` pour le natif) | conflits d'entités ; liste de Locations de l'image écrasée ; quota GitHub | code du plugin 1.3.3 lu | coexistence et migration sur k3d |
| **D9** | Backstage : base de données | SQLite éphémère tant que tout le catalogue dérive de Git et de l'API ; PostgreSQL (CNPG plateforme) seulement pour 2 réplicas (doc *production-sizing* : 2+ réplicas exigent PostgreSQL) | sessions perdues au redémarrage | redémarrage = catalogue reconstruit en ≤ 120 s (`docs/PORTAL.md`) | — |
| **D10** | `capabilities.yaml` : `identityProviders` | passer OKE et k3d de `thunderid` à `authentik` (décision déjà actée, `STATE.md` « Décision d'architecture ») | apps générées encore marquées ThunderID | — | — |

## Ce qui n'est PAS à décider ici

Le choix des outils est acté (OpenChoreo, Backstage, Argo, Kyverno, OpenBao, Doppler, ESO, Authentik) : aucune nouvelle étude comparative.
