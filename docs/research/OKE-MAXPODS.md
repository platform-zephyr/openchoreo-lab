# Plafond de pods sur OKE : où il est, comment le relever, si cela vaut le coup

Date : 2026-11-19. Ticket : T-518. Étude en lecture seule : rien n'a été appliqué sur le cluster, rien n'a été écrit dans homelab-infra. Niveaux de preuve : [M] mesuré dans ce dépôt, [S] lu dans le code d'infrastructure, [E] estimé, [NV] non vérifié.

## 1. Décision et règle

Décision de Paul (2026-11-19) : « enlève cette limite durant la phase de test ». Règle retenue :

- De maintenant à la décision de porte (ADR-0020), les 33 pods ne limitent pas les apps de test.
- Les 33 pods restent un critère de mesure de la plateforme seule (C2). Ils ne sont pas un plafond d'apps. Les ADR ne sont pas modifiés (périmètre GOV) ; `thresholds.yaml` non plus.
- Le seul plafond de pods est celui du kubelet (`maxPods`), tant que le CPU le permet (§2).
- Les 70 % de requests suivent la même logique que les 33 pods (extension T-518b, §5) : critère de PORTE pour la plateforme seule (C2), pas plafond physique. Pour les apps de test, le plafond réel est l'allocatable du nœud (~1830m), avec une marge de sécurité ≤ 90 %. `capacity_gate` de `tools/oke/lib.sh` applique les 70 % à l'installation de la plateforme ; il n'est pas modifié ici (fichier hors périmètre).

Contrôles automatisés relus : aucun n'échoue à 33 pods [S]. `tools/oke/measure.sh` affiche l'allocatable en pods sans le comparer. `tools/oke/verify.sh` ne compte pas les pods. `tools/oke/preflight.sh` bloque l'installation si `pods + 20 > allocatable` : c'est une marge d'installation de la plateforme, pas un seuil d'apps. Le critère « FAIL si > 33 pods » n'existe qu'en prose (brief du POC, T-487), il est précisé dans cette PR. Aucun changement de script nécessaire. Si un contrôle de pods est ajouté plus tard à `lib.sh` (proposé dans `docs/architecture/TARGET-ARCHITECTURE.md` §8), le changement minimal sera de le limiter à la plateforme seule, hors namespaces d'apps de test.

## 2. Où est le plafond réel

1. **CPU, d'abord, mais pas à 70 %** [M/E] : avec le bras O actif, 32 pods (T-487, `measure.sh`, 2026-11-19) ; les notes donnent à la fois « 52 % » et « ~141m avant 70 % », deux valeurs incohérentes entre elles (52 % de 1830m = ~950m ; 141m avant 1281m = ~1140m, soit 62 %) [NV : à relever à nouveau par T-515]. Dans les deux cas la marge avant le plafond de sécurité de 90 % (~1647m) est d'environ 500m à 700m, soit une dizaine de pods de 50m, et non « un pod ». La marge de « 141m » n'est que la marge avant le critère de porte de 70 %, qui ne s'applique pas aux apps de test.
2. **`maxPods` du kubelet** : 35 d'après les notes de mission [M, à relire par T-515] ; 33 pods présents, donc 2 de marge.
3. **IP de pods VCN-native** [S] : le node pool pose `max_pods_per_node = 31`, avec le commentaire « 31 IP par VNIC secondaire ; 2 OCPU A1 = 2 VNIC ; donc 31 pods par nœud ». Les pods en `hostNetwork` n'utilisent pas d'IP VCN, ce qui peut expliquer 33 pods présents pour 31 IP. Écart à lever : 35 (mission) contre 31 (Terraform). Seule la lecture de `allocatable.pods` du nœud et le compte des pods hors `hostNetwork` (T-515) le tranchent [NV].

Conséquence : relever `maxPods` seul n'aide que si le CPU suit. Avec ~500 à 700m de marge avant 90 %, les apps de test peuvent ajouter de l'ordre de dix pods de 50m ; le `maxPods` (2 pods de marge sur 35) est donc probablement atteint avant le CPU, ce qui renverse la conclusion antérieure « le CPU bloque d'abord » [E, à confirmer par T-515].

## 3. Options pour relever `maxPods`

Le node pool est géré dans homelab-infra, racine `terraform/oracle-a1` (pas dans `terraform/oracle-cloud`, qui ne porte que le réseau, la surveillance, le stockage objet et l'administration) [S]. Il décrit un seul nœud A1 (2 OCPU, 12 Go), réseau VCN-native, sans réglage kubelet ni cloud-init.

| Option | Principe | Coût et risques |
|---|---|---|
| **A. `max_pods_per_node` seul** | Augmenter la valeur du node pool dans Terraform | Sans effet utile : le plafond suivant est le nombre d'IP de pods (31 par VNIC secondaire, 1 VNIC secondaire avec 2 OCPU) [S]. Le nœud doit de toute façon être recréé pour prendre la valeur [NV]. À écarter. |
| **B. Kubelet extra args / cloud-init** | Passer `--max-pods` via les métadonnées du node pool (script d'init OKE) | Même recréation du nœud, et en VCN-native OKE dimensionne `maxPods` sur les IP disponibles : forcer plus de pods que d'IP donne des pods sans IP [E]. Réglage non prévu dans la configuration actuelle. À écarter. |
| **C. Plus de VNIC : 4 OCPU / 24 Go** | `node_ocpus` 4 ; plus d'OCPU, plus de VNIC, donc plus d'IP de pods (3 VNIC secondaires, soit 93 en théorie [E]) | Le garde-fou actuel interdit 4/24 (validation à 2 OCPU maximum, quota 2/12). Le surcoût estimé est d'environ 28 USD par mois pour +2 OCPU / +12 Go en PAYG [E] (`docs/research/HOMELAB-CAPACITY-DATAPLANE.md` §4). Un agent ne relève jamais le quota (ADR-0017 §7) : décision de Paul. Le nœud est remplacé. Chiffre de coût : voir §6 (non établi). |
| **D. Second nœud 2/12** | Deuxième nœud dans le pool : 2 × 35 pods, et le CPU double | Même surcoût que C (≈ 28 USD/mois, [E] non vérifié, §6), mais le nœud existant n'est pas remplacé (redimensionnement du pool) [E]. C'est l'option B de `docs/architecture/TARGET-ARCHITECTURE.md` §7, déjà recommandée pour d'autres raisons (capacité, second domaine de panne). |
| **E. Retirer des pods de la plateforme** | Argo CD en mode core (−1 pod, −64 Mi, `docs/PHASE-B.md` §4), puis Flux, composants optionnels coupés | 0 €, pas de recréation, mais le gain est petit (quelques pods). Les requests ne se baissent jamais pour passer un test. |

Coût d'une recréation de nœud (A, B, C) [M/S] : le nœud unique porte tout ; recréer le nœud, c'est perdre l'état local et réinstaller la plateforme. L'installation complète a duré environ 30 min (T-487, 22:35Z à 23:05Z), plus les vérifications. À cela s'ajoutent la fenêtre ARC et un MANDAT (cluster et node pool sont recréés par la valeur `cluster_generation` de homelab-infra), la réinstallation de Cilium en chaining et de la règle `deny-imds`, et la reprise de `lab-pg` (volume de 50 Go) depuis sa sauvegarde. Cela relève de la section « maintenance » de Paul, pas d'un agent.

## 4. Recommandation

1. Ne rien recréer pour l'instant. Faire d'abord le relevé de T-515 : `allocatable.pods` réel, pods hors `hostNetwork`, marge de CPU. C'est lecture seule et ne coûte rien.
2. Si la marge de pods bloque les apps de test : **E d'abord** (0 €, quelques pods), puis **D** si Paul accepte le surcoût (≈ 28 USD par mois [E], non vérifié, §6). D est préférable à C : il ne remplace pas le nœud et double CPU et pods (§2).
3. Relever seulement `maxPods` (A, B) ne vaut pas le coup : une recréation du nœud pour un plafond d'IP qui ne bouge pas.
4. Seule la décision de porte tranche si le POC mérite un second nœud payant ; le choix de la voie (une plateforme seule dans 33 pods, ou plus de capacité) y revient.

## 5. Extension T-518b : le CPU

- Les 70 % de requests (D-2026-11-15-05) sont un critère de porte pour la plateforme seule, comme les 33 pods. Ils restent dans les ADR et `thresholds.yaml`, non modifiés.
- Pour les apps de test : plafond réel = allocatable du nœud (~1830m [M]), marge de sécurité ≤ 90 % (~1647m), pour garder de la place aux rollouts et au système. Au-delà : arrêter et décider, sans baisser de request.
- Corrigés dans cette PR : cette étude, `docs/ORCHESTRATION.md` (relevé d'empreinte), `docs/research/POC-BRIEF-SESSION-LOCALE.md` (empreinte). Les autres mentions de 70 % décrivent le budget de la plateforme (porte) et restent exactes.

## 6. Vérification du chiffre « ≈ 28 USD/mois » d'un second nœud (T-518b)

- **Établi** (page Oracle Always Free, lue le 2026-11-19) : A1 = « 1 500 heures OCPU et 9 000 heures Go par mois gratuits pour tous les tenancies », équivalent à 2 OCPU / 12 Go ; 1 instance de 2 OCPU ou 2 de 1 OCPU ; la page ne mentionne pas 4 OCPU / 24 Go ; Oracle ne facture que l'usage au-dessus des limites Always Free après passage en PAYG. Le nœud actuel (2 OCPU / 12 Go) consomme déjà tout le gratuit ; un second nœud 2/12 est donc intégralement payant. L'hypothèse « 4/24 gratuit » est contredite par la page [documentation Oracle]. Le quota du dépôt d'infrastructure fixe 2/12 et interdit 4/24 [S, lecture seule].
- **Non établi (NOT_TESTED)** : le montant. Il vient de (2 × 0,01 + 12 × 0,0015) $/h × 730 h = 27,7 $ ; les tarifs unitaires A1 ne sont pas relus (la page de tarifs Oracle répond 403 depuis ici). « ≈ 28 USD/mois » reste une estimation [E], à confirmer par Cost Analysis ou le simulateur Oracle avant toute décision de Paul. Aucun essai de facturation réel n'a été fait.
- Si le compte est en Always Free pur (pas PAYG), le second nœud est impossible plutôt que payant ; le dépôt le décrit en PAYG avec quota, ce qui n'a pas été revérifié ici [NOT_TESTED].
- L'option B′ de `docs/architecture/TARGET-ARCHITECTURE.md` (§7, agrandir à 4/24) est payante pour la même raison.

## 7. Écart `max_pods_per_node = 31` (Terraform) contre 35 (kubelet) (T-518b)

- **Établi (31)** : Oracle documente, pour le réseau de pods VCN-native, `max pods = MIN((nombre de VNIC − 1) × 31, 256)` (page « OCI VCN-Native Pod Networking CNI plugin », lue le 2026-11-19). Avec 2 VNIC (A1 à 2 OCPU, d'après le commentaire Terraform ; le nombre de VNIC de la forme n'est pas relu sur la page des formes [NOT_TESTED]), on obtient (2 − 1) × 31 = 31, qui est la valeur posée dans le node pool [S].
- **Non expliqué (35)** : la valeur 35 vient des notes de mission (`allocatable.pods` du kubelet) ; aucune source lue ici ne l'explique. Piste, non vérifiée : le kubelet annonce sa propre limite, indépendante des IP VCN, et les pods en `hostNetwork` ne prennent pas d'IP de pod. Statut : **NOT_TESTED** jusqu'à la lecture de `allocatable.pods` et du compte de pods hors `hostNetwork` (T-515). Le plafond effectif pour des pods avec IP de pod est donc 31 (si l'IP est le facteur limitant), pas 35.

Rien ici n'est appliqué. Toute valeur d'identifiant, d'adresse ou d'hôte reste hors du dépôt.
