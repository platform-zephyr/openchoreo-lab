---
owner: paul
updated: 2026-11-18
review_days: 7
---
# Brief : session Claude locale d'exécution cluster (OKE d'abord)

À coller tel quel dans une session Claude Code ouverte sur le Mac de Paul, dans un clone à jour de ce dépôt.
Stratégie : [POC-OPENCHOREO-STRATEGY.md](POC-OPENCHOREO-STRATEGY.md) §6 (étapes E4, E5) ; tickets T-487, T-005.
Ce brief ne contient aucune valeur sensible et ne doit en recevoir aucune.

---

```text
Tu es la session locale d'exécution cluster du dépôt openchoreo-lab (dépôt PUBLIC). Réponds en français, conclusion
d'abord. Lis AGENTS.md, STATE.md, docs/research/POC-OPENCHOREO-STRATEGY.md §3 et §6, backlog/T-487 et backlog/T-005.
Charge les skills platform-guardrails et openchoreo-setup.

OBJECTIF
E4 (T-487) : sur le cluster OKE recréé vierge par homelab-infra (T-490 fusionné et appliqué), installer la plateforme
depuis Git avec tools/oke/install.sh (étapes 0 à 11, 10 = CNPG lab-pg), un seul Argo CD (lab-argocd), AppProjects
lab-o et lab-k, puis mesurer l'empreinte. E5 (T-005) : après la fusion des PR de T-005, T-489 et T-491, faire la
synchro manuelle de lab-platform et prouver qu'un check run est publié dans GitHub depuis OKE. Si T-006 est
fusionné, la même synchro livre cloudflared (lecture MCP seulement) : vérifie que l'apiserver ne répond pas par
l'hôte public. N'expose jamais l'apiserver, Argo ni un port d'administration.

PRÉREQUIS (vérifie, ne contourne pas ; s'il en manque un : BLOCKED et stop)
- PR de homelab-infra T-490 fusionnée et apply ARC terminé : cluster OKE vierge (aucun Argo, aucune Application).
- Paul a ouvert la session bastion ; KUBECONFIG dédié à cette session, contexte kubectl explicite à chaque commande.
- Le cluster est arm64 ; security/bundle.lock correspond au bundle 1.0.1 (install.sh refuse sinon : c'est voulu).
- Pour E5 : clés de l'App openchoreo-status présentes dans Doppler (noms dans T-489), lues par ESO, jamais par toi.

PÉRIMÈTRE D'ÉCRITURE
- Cluster : uniquement ce que font tools/oke/install.sh et une synchro Argo des Applications du labo ; écriture
  limitée aux namespaces openchoreo-* et lab-* et aux objets cluster-scoped nommés dans les AppProjects du labo.
- Dépôt : une branche claude/t-487-preuves-oke ; preuves datées sous backlog/evidence/ et docs/state/journal/ ;
  cases de T-487 et T-005 cochées seulement avec leur preuve. Commit Conventional avec trailer Ticket:, push, PR.

INTERDITS
- Aucun kubectl apply/patch/delete hors install.sh ; aucun changement durable hors Git ; aucun MCP en écriture.
- Aucune écriture hors openchoreo-* et lab-* ; aucune suppression d'un objet que le labo n'a pas créé.
- Ne désactive ni ne contourne une VAP, la PSA, une NetworkPolicy, une fenêtre de synchro Argo ou une garde ;
  un refus d'une garde se signale, il ne se contourne pas.
- Ne lis, n'affiche, ne copie aucun secret, jeton, kubeconfig, clé, IP, OCID, nom d'hôte interne ou e-mail.
- Aucun Service LoadBalancer, aucun volume au-delà de 50 Go pour lab-pg, aucune dépense : tout dépassement = stop.
- Ne touche ni au homelab, ni aux dépôts kube-ops et homelab-infra, ni à Colima (repli seulement, sur demande de Paul).

PREUVES À RENDRE (chacune datée en UTC, avec la commande de lecture qui la produit)
1. tools/oke/verify.sh : PASS ou FAIL par étape 0 à 11 ; durée totale de l'installation.
2. Un seul Argo CD dans le cluster ; lab-root Synced ; AppProjects lab-o et lab-k présents ; test de refus d'une
   destination hors périmètre (Argo refuse, preuve par l'événement).
3. Empreinte (méthode de tools/oke/measure.sh) : requests CPU et RAM en % de l'allouable, nombre de pods, avec la
   plateforme seule puis avec un bras actif. FAIL si > 70 % ou > 33 pods.
4. lab-pg Ready ; volume de bloc ≤ 50 Go.
5. E5 : check run d'une app témoin (whoami) publié sur le commit synchronisé, lu par l'API GitHub publique ; puis un
   FAIL volontaire typé (digest faux par PR de test) publié en failure.

FORMAT DU COMPTE RENDU (STE80)
Objective / Status (PASS | FAIL | BLOCKED | NOT_TESTED, niveau RUNTIME OKE) / Changes (PR, commits) /
Evidence (tableau : preuve, verdict, horodatage, fichier) / Blockers (noms seulement) / NextAction.
k3d n'est pas OKE ; aucune preuve sans horodatage n'est PASS ; dis INCOMPLET quand c'est le cas.
```
