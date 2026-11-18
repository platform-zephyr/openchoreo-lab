# Mesures du homelab (T-360) : le geste de Paul (procédure)

Statut : le relevé n'a pas encore été lancé. Aucune valeur n'est connue : tout ce qui suit est `NOT_TESTED` tant que Paul n'a pas collé la sortie.

## Pourquoi
T-360 bloque une soixantaine de tickets : sans mesures, ni le budget RAM de 64 Gio, ni la taille des VM kube-ops et lab ne sont décidables. L'agent n'a pas accès à l'hôte Proxmox. Le script `tools/homelab/measure.sh` réduit le geste à une commande de lecture et à un copier-coller.

## La commande (sur l'hôte Proxmox, en shell ; root conseillé, `sudo` inutile)
```bash
REF=main; curl -fsSL "https://raw.githubusercontent.com/platform-zephyr/openchoreo-lab/$REF/tools/homelab/measure.sh" -o measure.sh && bash measure.sh > homelab-mesures.yaml
```
- Le script est public et lisible (`less measure.sh`) ; sans accès au dépôt depuis l'hôte, le copier avec `scp` depuis un poste.
- Avant la fusion de la PR, remplacer `REF=main` par `REF=claude/t-360-script-mesure`.
- Durée : quelques secondes. La progression passe sur le terminal, le YAML dans `homelab-mesures.yaml`.
- Avec l'historique Prometheus (recommandé : seule source des 14 jours de p50 / p95 / pic) : préfixer la commande `bash` par `PROM_URL=http://<adresse-de-prometheus>:9090`, adresse saisie par Paul seul (jamais écrite dans le dépôt ni dans la sortie). Sans elle, le script se rabat sur l'historique RRD de Proxmox (`pvesh`, moyennes lissées) puis sur `sar` (hôte entier, pas la VM).
- Si le nom des VM ne contient ni `kube`, `talos`, `k8s` ni `lab`, ajouter `KUBEOPS_VMID=<n>` et `LAB_VMID=<n>` (numéros jamais écrits dans la sortie).

## Ce que le script fait et ne fait pas
- Lecture seule stricte : seules `qm list|config`, `pvesh get`, `pvesm status`, `zpool list|status`, `sensors`, `sar`, `arc_summary`, `df` et, si `PROM_URL` est fourni, des `curl -G` (GET) vers Prometheus. Une garde interne refuse toute autre commande. Aucune mutation, aucun fichier temporaire, aucun `sudo`.
- Aucun envoi réseau, hormis ces GET vers l'adresse donnée par Paul.
- Sortie anonymisée : aucune IP, aucun nom d'hôte, de VM, de pool ou de stockage, aucun UUID ni MAC. Les VM sont `vm-kube-ops` et `vm-lab`. Relire la sortie avant de la coller reste une bonne habitude.
- Une mesure impossible rend `status: NOT_AVAILABLE` et une raison (outil absent, droits, pas de source). Ce n'est pas une erreur : la coller telle quelle.

## Coller la sortie
Coller le contenu de `homelab-mesures.yaml` dans le fil de la session (ou le joindre au ticket T-360 sur le dépôt). Rien d'autre à faire.

## Ce que l'agent en fera
1. Lire la sortie. Une section `NOT_AVAILABLE` reste ouverte et nomme ce qu'il manque (ex. `PROM_URL`) ; l'agent redemande ce relevé précis, pas tout.
2. Créer `docs/state/homelab-capacity.yaml` avec le tableau daté : p50, p95 et pic du CPU et de la RAM de la VM kube-ops (sur 14 jours), usage NVMe et miroir HDD, Tctl, plafond ARC ZFS, source et commande de chaque ligne. Le fichier n'existe pas encore : il n'est pas rempli avec des valeurs supposées.
3. Versionner le budget RAM de 64 Gio avec des seuils d'alerte à 80 % (51,2 Gio) : allocation des VM, plafond ARC, marge de l'hôte, RAM libérable.
4. Proposer la taille cible des VM kube-ops et lab (vCPU, RAM, disque) à partir du p95 avec marge, et la soumettre à Paul (ADR-0003, ADR-0017 : un agent ne relève jamais un plafond).
5. Cocher les critères de T-360 avec la date et la commande de la preuve, puis passer le ticket à `done`.

## Mesure facultative : RAM libérable (arbitrage 3)
Pour mesurer ce que libère l'arrêt de services de kube-ops, relever deux fois la seule section RAM, avant puis après l'arrêt (l'arrêt est une décision de Paul sur kube-ops, hors de ce dépôt) :
```bash
bash measure.sh --only ram,arc,vms --label avant > avant.yaml
bash measure.sh --only ram,arc,vms --label apres > apres.yaml
```
L'agent compare `host_mem_available_gib`, `reclaimable_estimate_gib` et `host_rss_mib` de `vm-kube-ops`.

## Limites connues
- Tctl, ARC, RAM libérable et usage disque sont des relevés instantanés : sans `PROM_TCTL_QUERY`, pas de p95 de température sur 14 jours.
- L'historique RRD de Proxmox est lissé : il sous-estime les pointes. Le p95 de référence vient de Prometheus.
- `media_guess` (NVMe ou non) se déduit du nom des disques ; Paul le confirme au moment de la décision.
- Test hors hôte : `bash tests/homelab/measure_test.sh` (commandes simulées). Aucune exécution réelle sur Proxmox n'a encore eu lieu : `NOT_TESTED` jusqu'au retour de Paul.
