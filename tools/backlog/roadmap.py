import re,glob,functools,collections
import os as _os
ROOT = _os.path.abspath(_os.path.join(_os.path.dirname(__file__), '..', '..'))
ALL={}
for f in sorted(glob.glob(ROOT+'/backlog/T-*.md')):
    s=open(f).read(); g=lambda k: re.search(rf'^{k}: (.*)$',s,re.M).group(1).strip()
    o=lambda k: (re.search(rf'^{k}: (.*)$',s,re.M).group(1).strip() if re.search(rf'^{k}:',s,re.M) else '')
    ALL[g('id')]=dict(f=f.split('/')[-1],st=g('status'),stage=g('stage'),deps=[d.strip() for d in g('depends_on').strip('[]').split(',') if d.strip()],
                    v=g('velocity')=='true',lane=g('lane'),cls=g('class'),title=g('title').strip('"'),model=o('model'),effort=o('effort'))
T={k:v for k,v in ALL.items() if v['st']=='todo'}
@functools.lru_cache(None)
def W(n): return max([W(d)+1 for d in T[n]['deps'] if d in T]+[0])
ch=collections.defaultdict(set)
for n,x in T.items():
    for d in x['deps']:
        if d in T: ch[d].add(n)
@functools.lru_cache(None)
def desc(n):
    r=set(ch[n])
    for c in ch[n]: r|=desc(c)
    return frozenset(r)
@functools.lru_cache(None)
def anc(n):
    r=set(d for d in T[n]['deps'] if d in T)
    for d in list(r): r|=anc(d)
    return frozenset(r)
for n in T: T[n]['w']=W(n); T[n]['u']=len(desc(n))
ORDER=['S0','S1','S2','S3','PORTE','FINAL0','I1','I1bis','I2','I3','I4','I5','I6','I7','I8','FINAL','I9']
NAMES={'S0':'MVP — S0 minimal du pilote 24 h (garde de fuite, ADR, exécutant, dispatcher, PAUSE, réglages)','S1':'MVP — pilote 24 h, VM lab, moteur OpenChoreo (CP sur le homelab), accès des agents cloud',
 'S2':'MVP — second moteur (plain), travailleur homelab, mesures','S3':'MVP — golden path, intentions, banc et étalonnage',
 'PORTE':"Porte d'adoption OpenChoreo (2026-12-04)",'FINAL0':'Durcissement avant la première donnée réelle ou exposition publique','I1':'Données','I1bis':'Archétypes D et E','I2':'Secrets et identité','I3':'Exposition, admission, première app familiale',
 'I4':'Exploitation : observabilité, remédiation, ntfy','I5':'Montées de version','I6':'Migration Doppler, rotation, audit','I7':'Services IA (homelab)','I8':'Mesure (DORA, maturité)','FINAL':'Durcissement final (obligatoire avant « plateforme finie »)','I9':'Divers'}
SHORT={'claude-haiku-5-5':'haiku','claude-sonnet-5-5':'sonnet','claude-opus-5-5':'opus','human':'humain'}
def L(n): return f"[{n}]({ALL[n]['f']})"
def M(x): return f"{SHORT.get(x['model'],x['model'])}/{x['effort']}"
md=["""# Feuille de route (générée depuis `backlog/`)

Ordonnancement issu du **consensus n°2 et des arbitrages de Paul** (`docs/review/CONSENSUS-2.md`, 2026-11-18 ; résumé :
`backlog/INTEGRATION-3.md`), puis de l'**arbitrage Fable** (`docs/review/FABLE-ARBITRAGE.md` ; résumé : `backlog/INTEGRATION-4.md`),
après le consensus n°1 (`docs/review/CONSENSUS.md`) et l'intégration 2. Objectif de Paul : finir
vite avec un maximum d'agents en parallèle ; la sécurité de développement est réduite, **seule la sécurité finale compte**
(étape FINAL0 avant la première donnée réelle, étape FINAL avant « plateforme finie »).

## Règles
1. **Étapes dans l'ordre** : MVP (S0 → S3), puis la **porte OpenChoreo** en mono-cluster (ADR-0020 amendé), puis **FINAL0**
   (identité d'usine, contournement retiré, secrets de dev tournés), puis des **incréments** (I1 → I8), puis le **durcissement final** (FINAL) avant de déclarer la plateforme finie. Une étape peut
   démarrer dès que les dépendances de ses tickets sont `done`.
2. **Dans une étape** : par vague de dépendances, d'abord les tickets `velocity`, puis ceux qui débloquent le plus.
3. **Parallélisme** : pilote à N=3 (`max-parallel` ou groupes par couloir) sur une liste figée de 20 tickets ; paliers 3 → 6 → 10 décidés par Paul (ADR-0021) ; au plus
   2 agents par couloir, 1 sur `contrat-appgen` avant T-214 ; aucun chevauchement de périmètre (T-210 minimal, T-314). En mode dev, REVUE = merge après `ci-ok`.
4. **Modèle** (ADR-0023, 3 règles) : noyau (chemins CODEOWNERS, `docs/adr/`, `docs/review/`) → opus/high ; texte hors noyau →
   haiku/medium + revue Sonnet ; reste → sonnet/high. Le dispatcher recalcule depuis les chemins et ignore un `model:` sous le plancher.
5. **Règle d'usine** (ADR-0021) : avant la porte, un ticket d'usine n'entre que s'il supprime un geste de Paul mesuré au pilote.
6. **MVP** = une app A sur le homelab (VM lab, CP OpenChoreo sur le homelab), en prod, livrée à partir d'une phrase, avec
   preuve datée sans coordinateur. DeepSeek : après le chantier.
"""]
md.append("## Gestes de Paul\n\nMANDAT = geste de Paul (accès, identité, dépense, VM) ; REVUE = approbation d'une PR du noyau. Ordre = vague.\n")
md.append("| Étape | Gestes (MANDAT) | Approbations (REVUE) |\n|---|---|---|")
for st in ORDER:
    srt=lambda N: sorted(N,key=lambda n:(T[n]['w'],n))
    G=srt([n for n in T if T[n]['stage']==st and 'MANDAT' in T[n]['cls']])
    R=srt([n for n in T if T[n]['stage']==st and 'REVUE' in T[n]['cls'] and 'MANDAT' not in T[n]['cls']])
    if G or R: md.append(f"| {st} | "+", ".join(L(n) for n in G)+" | "+", ".join(L(n) for n in R)+" |")
H=[n for n in T if T[n]['model']=='human']
if H: md.append("\nGestes purement humains (aucun agent) : "+", ".join(f"{L(n)} {T[n]['title']}" for n in sorted(H)))
# Lancement 24/7 : liste figée du pilote (lue dans T-322) et ses prérequis
PILOT='T-322'; AFTER=['T-315','T-316','T-006']
if PILOT in T:
    src=open(ROOT+'/backlog/'+ALL[PILOT]['f']).read()
    m=re.search(r'Liste figée du pilote \(\d+\) : ([^\n]*)',src)
    LIST=re.findall(r'T-\d+[a-z]?',m.group(1)) if m else []
    PRE=sorted(anc(PILOT),key=lambda n:(T[n]['w'],n))
    md.append(f"\n## Lancement 24/7\n\nPilote de **24 h à N=3** en dispatch manuel ({L(PILOT)}) : coût par ticket, % de quota 5 h et hebdomadaire,"
              " concurrence cloud ; puis paliers 6 et 10 décidés par Paul. Il ne dépend ni de T-215 ni du ruleset (FINAL0), ni de T-061/T-061b"
              " (actés par la fusion de la PR #48). Moteur horaire d'Atlas/homelab-infra en pause pendant les 24 h.\n")
    md.append(f"### Prérequis : S0 minimal ({len(PRE)} tickets)\n\n| Ticket | Titre | Vague | Classe | Modèle |\n|---|---|---|---|---|")
    for n in PRE: md.append(f"| {L(n)} | {T[n]['title']} | {T[n]['w']} | {T[n]['cls']} | {M(T[n])} |")
    md.append(f"\n### Liste figée du pilote ({len(LIST)} tickets, aucun autre lancement pendant le pilote)\n\n| Ticket | Titre | Étape | Classe | Modèle | Dépend de (hors S0) |\n|---|---|---|---|---|---|")
    for n in LIST:
        if n in T: md.append(f"| {L(n)} | {T[n]['title']} | {T[n]['stage']} | {T[n]['cls']} | {M(T[n])} | {', '.join(d for d in T[n]['deps'] if d in T and d not in PRE) or '—'} |")
        else: md.append(f"| {n} | (absent ou non `todo`) | | | | |")
    md.append("\nAprès le pilote : activation du cron T-314, puis "+", ".join(f"{L(n)} ({T[n]['stage']})" for n in AFTER if n in T)+".")
# Chemin critique
end=max(T,key=lambda n:(T[n]['w'],n in ('T-211',)))
path=[end]
while True:
    ds=[d for d in T[path[-1]]['deps'] if d in T]
    if not ds: break
    path.append(max(ds,key=lambda d:T[d]['w']))
md.append(f"\n## Chemin critique ({len(path)} vagues)\n\n"+" → ".join(L(n) for n in reversed(path)))
P=[n for n in T if T[n]['stage']=='PORTE']
for p in P:
    path=[p]
    while True:
        ds=[d for d in T[path[-1]]['deps'] if d in T]
        if not ds: break
        path.append(max(ds,key=lambda d:T[d]['w']))
    md.append(f"\nJusqu'à la porte ({len(path)} vagues) : "+" → ".join(L(n) for n in reversed(path)))
# Répartition des modèles
md.append("\n## Répartition des modèles (tickets `todo`)\n\n| Étape | haiku | sonnet | opus | humain |\n|---|---|---|---|---|")
for st in ORDER:
    N=[n for n in T if T[n]['stage']==st]
    if N:
        c=collections.Counter(SHORT.get(T[n]['model'],'?') for n in N)
        md.append(f"| {st} | {c['haiku']} | {c['sonnet']} | {c['opus']} | {c['humain']} |")
for st in ORDER:
    N=[n for n in T if T[n]['stage']==st]
    if not N: continue
    md.append(f"\n## {st} — {NAMES[st]} ({len(N)} tickets)\n\n| Ticket | Titre | Vague | Couloir | Classe | Modèle | Vélocité | Débloque |\n|---|---|---|---|---|---|---|---|")
    for n in sorted(N,key=lambda n:(T[n]['w'],-T[n]['v'],-T[n]['u'],n)):
        x=T[n]; md.append(f"| {L(n)} | {x['title']} | {x['w']} | {x['lane']} | {x['cls']} | {M(x)} | {'oui' if x['v'] else ''} | {x['u']} |")
G=[n for n,x in ALL.items() if x['st'] in ('deferred','blocked')]
md.append(f"\n## Gelés jusqu'à la porte ou bloqués par un déclencheur ({len(G)})\n")
md.append(", ".join(f"{L(n)} ({ALL[n]['st']})" for n in sorted(G)))
D=[n for n,x in ALL.items() if x['st']=='dropped']
md.append(f"\n\n## Absorbés ou supprimés ({len(D)})\n\n"+", ".join(L(n) for n in sorted(D)))
open(ROOT+'/backlog/ROADMAP.md','w').write('\n'.join(md)+'\n')
for st in ORDER:
    N=[n for n in T if T[n]['stage']==st]
    if N: print(st,len(N),'humains',sum(('MANDAT' in T[n]['cls'] or 'REVUE' in T[n]['cls']) for n in N),dict(collections.Counter(SHORT.get(T[n]['model'],'?') for n in N)))
print('todo',len(T),'gelés',len(G),'abandonnés',len(D))
