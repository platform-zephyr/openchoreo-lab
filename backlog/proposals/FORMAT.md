# Format des propositions de tickets (sous-agents → coordinateur)

Un fichier YAML par domaine : `backlog/proposals/<domaine>.yaml`, liste de tickets. Le coordinateur attribue les `T-xxx`.

```yaml
- key: OBS-1                 # clé locale unique dans le fichier (préfixe du domaine)
  title: "Titre court"
  phase: P0                  # P0..P5 (voir backlog/INDEX.md)
  adr: ["0011"]              # ADR existants, ou "NEW-<DOMAINE>" si un nouvel ADR est proposé dans le rapport
  depends_on: ["T-005", "OBS-0"]   # tickets existants (T-xxx) ou clés locales
  class: AUTONOME            # AUTONOME | REVUE | MANDAT, combinables "AUTONOME + MANDAT"
  velocity: true             # true si le ticket accélère nettement les suivants (outillage, parallélisme, feedback)
  parallel_lane: "observabilité"   # couloir où un agent peut travailler sans conflit de fichiers
  scope: "chemins de fichiers"
  intent: "une ou deux phrases"
  done: ["critère vérifiable 1", "critère vérifiable 2"]
  notes: "facultatif"
  absorbs: ["T-065"]         # tickets existants remplacés ou modifiés (facultatif), avec explication dans notes
```
