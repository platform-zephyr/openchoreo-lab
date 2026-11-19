# Plafond de pods sur OKE : où il est, comment le relever, si cela vaut le coup

Date : 2026-11-19. Ticket : T-518. Étude en lecture seule : rien n'a été appliqué sur le cluster, rien n'a été écrit dans homelab-infra. Niveaux de preuve : [M] mesuré dans ce dépôt, [S] lu dans le code d'infrastructure, [E] estimé, [NV] non vérifié.

## 1. Décision et règle

Décision de Paul (2026-11-19) : « enlève cette limite durant la phase de test ». Règle retenue :

- De maintenant à la décision de porte (ADR-0020), les 33 pods ne limitent pas les apps de test.
- Les 33 pods restent un critère de mesure de la plateforme seule (C2). Ils ne sont pas un plafond d'apps. Les ADR ne sont pas modifiés (périmètre GOV) ; `thresholds.yaml` non plus.
- Le seul plafond est celui du kubelet (`maxPods`), tant que la marge de CPU le permet (§2).
- Les 70 % de requests ne sont pas couverts par la décision : ils restent en vigueur. Ils sont appliqués à l'installation par `capacity_gate` de `tools/oke/lib.sh`.

Contrôles automatisés relus : aucun n'échoue à 33 pods [S]. `tools/oke/measure.sh` affiche l'allocatable en pods sans le comparer. `tools/oke/verify.sh` ne compte pas les pods. `tools/oke/preflight.sh` bloque l'installation si `pods + 20 > allocatable` : c'est une marge d'installation de la plateforme, pas un seuil d'apps. Le critère « FAIL si > 33 pods » n'existe qu'en prose (brief du POC, T-487), il est précisé dans cette PR. Aucun changement de script nécessaire. Si un contrôle de pods est ajouté plus tard à `lib.sh` (proposé dans `docs/architecture/TARGET-ARCHITECTURE.md` §8), le changement minimal sera de le limiter à la plateforme seule, hors namespaces d'apps de test.

## 2. Où est le plafond réel

1. **Marge de CPU, d'abord** [M] : avec le bras O actif, 32 pods et 52 % de CPU en requests (T-487, `measure.sh`, 2026-11-19) ; il reste environ 141m avant 70 %, soit à peu près un pod. C'est ce plafond que les apps de test touchent en premier, pas celui des pods.
2. **`maxPods` du kubelet** : 35 d'après les notes de mission [M, à relire par T-515] ; 33 pods présents, donc 2 de marge.
3. **IP de pods VCN-native** [S] : le node pool pose `max_pods_per_node = 31`, avec le commentaire « 31 IP par VNIC secondaire ; 2 OCPU A1 = 2 VNIC ; donc 31 pods par nœud ». Les pods en `hostNetwork` n'utilisent pas d'IP VCN, ce qui peut expliquer 33 pods présents pour 31 IP. Écart à lever : 35 (mission) contre 31 (Terraform). Seule la lecture de `allocatable.pods` du nœud et le compte des pods hors `hostNetwork` (T-515) le tranchent [NV].

Conséquence : relever `maxPods` seul n'aide que si la marge de CPU suit. Avec ~141m de marge, deux pods de plus de 50m chacun suffisent à atteindre les 70 %.

## 3. Options pour relever `maxPods`

Le node pool est géré dans homelab-infra, racine `terraform/oracle-a1` (pas dans `terraform/oracle-cloud`, qui ne porte que le réseau, la surveillance, le stockage objet et l'administration) [S]. Il décrit un seul nœud A1 (2 OCPU, 12 Go), réseau VCN-native, sans réglage kubelet ni cloud-init.

| Option | Principe | Coût et risques |
|---|---|---|
| **A. `max_pods_per_node` seul** | Augmenter la valeur du node pool dans Terraform | Sans effet utile : le plafond suivant est le nombre d'IP de pods (31 par VNIC secondaire, 1 VNIC secondaire avec 2 OCPU) [S]. Le nœud doit de toute façon être recréé pour prendre la valeur [NV]. À écarter. |
| **B. Kubelet extra args / cloud-init** | Passer `--max-pods` via les métadonnées du node pool (script d'init OKE) | Même recréation du nœud, et en VCN-native OKE dimensionne `maxPods` sur les IP disponibles : forcer plus de pods que d'IP donne des pods sans IP [E]. Réglage non prévu dans la configuration actuelle. À écarter. |
| **C. Plus de VNIC : 4 OCPU / 24 Go** | `node_ocpus` 4 ; plus d'OCPU, plus de VNIC, donc plus d'IP de pods (3 VNIC secondaires, soit 93 en théorie [E]) | Le garde-fou actuel interdit 4/24 (validation à 2 OCPU maximum, quota 2/12). Le surcoût estimé est d'environ 28 USD par mois pour +2 OCPU / +12 Go en PAYG [E] (`docs/research/HOMELAB-CAPACITY-DATAPLANE.md` §4). Un agent ne relève jamais le quota (ADR-0017 §7) : décision de Paul. Le nœud est remplacé. |
| **D. Second nœud 2/12** | Deuxième nœud dans le pool : 2 × 35 pods, et le CPU double | Même surcoût que C, mais le nœud existant n'est pas remplacé (redimensionnement du pool) [E]. C'est l'option B de `docs/architecture/TARGET-ARCHITECTURE.md` §7, déjà recommandée pour d'autres raisons (capacité, second domaine de panne). |
| **E. Retirer des pods de la plateforme** | Argo CD en mode core (−1 pod, −64 Mi, `docs/PHASE-B.md` §4), puis Flux, composants optionnels coupés | 0 €, pas de recréation, mais le gain est petit (quelques pods). Les requests ne se baissent jamais pour passer un test. |

Coût d'une recréation de nœud (A, B, C) [M/S] : le nœud unique porte tout ; recréer le nœud, c'est perdre l'état local et réinstaller la plateforme. L'installation complète a duré environ 30 min (T-487, 22:35Z à 23:05Z), plus les vérifications. À cela s'ajoutent la fenêtre ARC et un MANDAT (cluster et node pool sont recréés par la valeur `cluster_generation` de homelab-infra), la réinstallation de Cilium en chaining et de la règle `deny-imds`, et la reprise de `lab-pg` (volume de 50 Go) depuis sa sauvegarde. Cela relève de la section « maintenance » de Paul, pas d'un agent.

## 4. Recommandation

1. Ne rien recréer pour l'instant. Faire d'abord le relevé de T-515 : `allocatable.pods` réel, pods hors `hostNetwork`, marge de CPU. C'est lecture seule et ne coûte rien.
2. Si la marge de pods bloque les apps de test : **E d'abord** (0 €, quelques pods), puis **D** si Paul accepte ~28 USD par mois. D est préférable à C : il ne remplace pas le nœud et double le CPU, qui est le vrai plafond (§2).
3. Relever seulement `maxPods` (A, B) ne vaut pas le coup : une recréation du nœud pour un plafond d'IP qui ne bouge pas, avec le CPU qui bloque avant.
4. Seule la décision de porte tranche si le POC mérite un second nœud payant ; le choix de la voie (une plateforme seule dans 33 pods, ou plus de capacité) y revient.

Rien ici n'est appliqué. Toute valeur d'identifiant, d'adresse ou d'hôte reste hors du dépôt.
