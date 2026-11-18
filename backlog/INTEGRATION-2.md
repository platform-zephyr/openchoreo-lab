# Intégration 2 du backlog (2026-11-18 soir)

Conclusion : 70 propositions (SEC 4, FAC 16, HAR 23, HOME 14, MOD 13) donnent **51 tickets nouveaux** et **19 fusions** dans des
tickets existants. Backlog : **134 `todo`, 29 gelés (`deferred`/`blocked`), 26 abandonnés** ; `check.py` : 0 erreur, profondeur 11.
Chaque ticket actif porte `model`, `effort` et `routing`. Source : patch « Intégration 2 » de `tools/backlog/seed.py`.
Statut : PROPOSITION (STATIC). Rien n'est exécuté ; le noyau (`docs/adr/`, `tools/backlog/`) attend l'approbation de Paul.

## Correspondance clé → ticket
| Clés | Ticket |
|---|---|
| SEC-1, SEC-2, SEC-3, SEC-4 | T-300, T-301, T-302, T-303 |
| FAC-1 / FAC-2 / FAC-3 / FAC-4 | fusionné dans T-215 / T-311 / fusionné dans T-210 / T-313 |
| FAC-5 … FAC-14 | T-314 … T-323 (FAC-n → T-309+n) |
| FAC-15 / FAC-16 | fusionné dans T-008 / T-325 |
| HAR-0, 1, 2, 4 | T-330, T-331, T-332, T-334 |
| HAR-3 / HAR-5 / HAR-6 | fusionné dans T-313 / T-210 / T-303 |
| HAR-7 … HAR-20, HAR-22 | T-337 … T-350, T-352 (HAR-n → T-330+n) |
| HAR-21 | fusionné dans T-323 |
| HOME-0 … HOME-5, HOME-7, HOME-8, HOME-12 | T-360 … T-365, T-367 (`blocked`), T-368, T-372 (`blocked`) |
| HOME-6 / HOME-9 / HOME-10 / HOME-11 / HOME-13 | fusionné dans T-031 / T-160 / T-022 / T-140 / T-061 |
| MOD-1 / MOD-2 / MOD-3 | fusionné dans T-061 / fusionné dans T-008 / T-382 |
| MOD-4 / MOD-5 | fusionné dans T-313 (passage du modèle ; trailers, schéma) + T-317 (escalade) / T-313 (+ collecte dans T-322) |
| MOD-6 / MOD-7 / MOD-8 | fusionné dans T-323 / T-386 / fusionné dans T-322 |
| MOD-9, MOD-10, MOD-11 / MOD-12 / MOD-13 | T-388, T-389, T-390 / fusionné dans T-350 / T-392 |
| Tickets existants | T-145 → `dropped`, fusionné dans T-311 ; T-209 → `dropped`, fusionné dans T-323 ; T-030 et T-213 → `deferred` (recadrés) |

## Décisions de dédoublonnage
1. **Identité** : T-215 garde son id (cité par le CONSENSUS) et absorbe FAC-1 (mandat de lot `mandate.v1`, App étendue au dispatch et au merge sous conditions). Classe `REVUE + MANDAT`.
2. **Dispatcher** : T-210 = cerveau (`next.py`, admission, couloirs, ressources exclusives, chevauchement de globs) ; absorbe FAC-3 et HAR-5.
   L'exécution passe à T-313 (FAC-4), qui absorbe HAR-3 (même fichier `claude-agent.yml`), le passage `--model/--effort` de MOD-4 et le schéma de MOD-5.
   Un seul schéma : `mission-result.v1` (pas de `model-run.v1`). L'escalade de modèle de MOD-4 va dans la reprise T-317.
3. **Quota** : FAC-2 (T-311) est plus complet que T-145 ; T-145 est abandonné et ses critères repris. MOD-8 (mesure du quota par modèle, repli à 70 %, plan) fusionne dans le pilote T-322.
4. **Lint** : T-008 absorbe FAC-15, MOD-2 et la règle « périmètre en globs » de HAR-5. La présence de `model`/`effort` est déjà vérifiée par `check.py`.
5. **Garde de fuite** : SEC-4 (T-303) absorbe HAR-6 ; le hook Stop (T-331) appelle le même script.
6. **Mesure de l'usine** : FAC-14 (T-323) absorbe MOD-6, HAR-21 et T-209 ; passe en S3 (nourrit l'étalonnage T-386).
7. **DeepSeek** : MOD-12 fusionne dans HAR-20 (T-350) : une seule voie, admise par le banc (pass^3 ≥ 0,8), données publiques seulement.
8. **Homelab** : HOME-6 → T-031 (test de reprise, C4 révisé) ; HOME-9 → T-160 (gVisor + vcluster sur lab) ; HOME-10 → T-022 (OpenBao sur lab) ;
   HOME-11 → T-140 (registre free tier) ; HOME-13 → T-061 (amendements).
9. **Revues** : FAC-12 (T-321, revue CI avant merge) et HAR-11 (T-341, sous-agent `reviewer` en session) restent séparés : deux étages différents.
10. **Reprise** : FAC-8 (T-317, code du dispatcher) et HAR-10 (T-340, protocole et skill) restent séparés, vocabulaire d'échec commun.
11. **Runners** : HAR-13 (T-343) tranche ; défaut (a) aucun runner homelab sur dépôt public. HOME-7 (T-367) est `blocked` sur l'option (b). FAC-9 (T-318) reste un travailleur en tirage sortant.

## Recommandation homelab intégrée
- VM Talos « lab » dédiée dès **S0** : T-360 (mesures), T-361 (VM), T-362 (isolation réseau) ; socle T-363 et OpenChoreo CP + DP co-localisés T-364 en **S1**.
- T-030 recadré « DP distant lab ↔ OKE selon D11 », `deferred` ; son cœur (Environments, app A) passe à T-364. Les tickets actifs qui dépendaient de T-030 dépendent de T-364.
- T-213 (Argo unique OKE) `deferred` ; l'emplacement d'Authentik passe à T-211. T-062 et T-212 visent le cluster lab.
- T-005 dépend de T-364 (preuve runtime sur le lab, plus sur OKE) ; T-003 garde une preuve k3d, sa preuve runtime passe à T-364.
- **Emplacement définitif du CP : non tranché.** Noté dans T-364 et T-211 (D11, décision de Paul à la porte).

## Vélocité
- S0 (24 tickets) : purge et garde de fuite (T-300-T-303), identité (T-215), lint (T-008), dispatcher (T-210) et exécutant (T-313), gouverneur (T-311),
  routage (T-382), assistant des gestes (T-325), harness (T-330, T-331, T-332, T-334), VM lab (T-360-T-362).
- S1 : cron (T-314), merge armé (T-315), revue (T-321), reprise (T-317), pilote (T-322), harness (T-337-T-341), T-214 avancé de S2 à S1.
- Sans T-061 (outillage ou urgence) : T-300-T-303, T-325, T-332, T-360. Tous les autres nouveaux tickets dépendent de T-061.
- T-301 (réécriture de l'historique) précède le pilote T-322 et le cron T-314 : sinon toutes les branches d'agents sont à recréer.

## Routage des modèles (`backlog/proposals/model-routing.yaml`)
Première règle qui s'applique. Sélecteurs (OU) : `lane` (motifs), `paths` (globs comparés au périmètre), `kind` (déduit du titre :
Acter/Porte = plan, Spike = research, Banc = bench, Veille = watch, Guide/Runbook = doc). Filtres (ET) : `class`, `keywords`.
Plancher = `floor`, sinon le modèle de la règle. Un modèle proposé n'est gardé que s'il est au-dessus (effort alors `high`).
« aucun (geste humain) » donne `model: human`, `effort: none` (T-300). Sonnet plafonné à `xhigh`.
Répartition des 134 tickets `todo` : sonnet 86, opus 45, haiku 2, humain 1.

## Vérification en ligne du 2026-11-18 (`docs/research/VERIFICATION-2026-11-18.md`)
1. A1 = 2 OCPU / 12 Go même en PAYG : critère dans T-140 (MISSION et STATE corrigés), T-061 ; T-132 : pas de nœud de surge, « Replace boot volume » ou coupure ; T-372 : tout dépassement est payant.
2. Grafana Free (stack récent) : webhook seul, ≤ 500 règles → T-100, T-107.
3. Agents SRE et Portal Assistant routables par agentgateway, FinOps non → note « option après porte » dans T-170 (reste supprimé).
4. Journal Doppler Developer = 3 jours → T-181 (décision export ou plan Team), T-193 (copie OpenBao vérifiée à chaque étape).
5. `GITHUB_TOKEN` ne déclenche pas la CI de ses PR, 1 000 req/h → T-215 (App obligatoire), T-201 (budget de requêtes).
6. SLSA Build L2 seulement avec attestations GitHub → T-203.
7. Rôles gérés CNPG : réalignement après restauration non documenté → test dans T-026.
8. OpenBao sur PostgreSQL (HA ≥ 2.7.0) et dépendance circulaire CNPG ↔ OpenBao → T-022.

## Nouveaux ADR à créer (dans T-061, noyau)
- ADR-0021 — Usine d'agents 24/7 et minimisation des interventions (texte : `docs/research/AGENT-FACTORY-24-7.md` §9).
- ADR-0022 — Harness et environnements de dev des agents (texte : `docs/research/AGENT-HARNESS.md` §5).
- ADR-0023 — Routage des modèles par tâche (texte : `docs/research/MODEL-ROUTING.md` §7).
- Amendements : ADR-0003 (deux clusters Talos, CP sur lab pendant la porte), ADR-0020 (C1, C2, C4), ADR-0017 (2/12, budget homelab ; acté avec T-218).

## Questions à Paul
1. T-061 devient lourd (12 ADR + 3 nouveaux + amendements) et reste en tête du chemin critique : le garder en une PR ou le scinder (existants / 0021-0023) ?
2. D11 à la porte : CP sur la VM lab ou sur OKE (non tranché ici).
3. Racine OpenTofu de la VM lab : `proxmox` existante ou `proxmox-lab` dédiée (T-361) ?
4. VM du travailleur homelab (T-318) : 8 vCPU / 32 Go proposés ne tiennent pas dans le budget 64 Gio avec la VM lab ; taille fixée par T-360 ?
5. Dépôt privé temporaire (T-300) : date cible de retour en public ?
6. Plan d'abonnement après le pilote (Max ou Ultra) et plafond de crédits d'usage (0 par défaut) ; MANDAT de dépense DeepSeek (T-350, T-389) ?
7. Doppler : export du journal vers un webhook ou plan Team (T-181) ?
8. Chemin critique (9 vagues jusqu'à la porte) passe par trois gestes homelab (T-360, T-361, T-362) : date possible de la séance S0 ?
