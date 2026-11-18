import re,glob,functools,collections
ALL={}
for f in sorted(glob.glob('/home/user/openchoreo-lab/backlog/T-*.md')):
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
ORDER=['S0','S1','S2','S3','PORTE','I1','I1bis','I2','I3','I4','I5','I6','I7','I8','I9']
NAMES={'S0':'MVP — socle de confiance, purge, identité, harness et usine (dispatch manuel)','S1':'MVP — preuve automatique, usine en marche, moteur OpenChoreo sur la VM lab',
 'S2':'MVP — second moteur (plain), travailleur homelab, mesures','S3':'MVP — golden path, intentions, banc et étalonnage',
 'PORTE':"Porte d'adoption OpenChoreo (2026-12-04)",'I1':'Données','I1bis':'Archétypes D et E','I2':'Secrets et identité','I3':'Exposition, admission, première app familiale',
 'I4':'Exploitation : observabilité, remédiation, ntfy','I5':'Montées de version','I6':'Migration Doppler, rotation, audit','I7':'Services IA (homelab)','I8':'Mesure (DORA, maturité)','I9':'Divers'}
SHORT={'claude-haiku-5-5':'haiku','claude-sonnet-5-5':'sonnet','claude-opus-5-5':'opus','human':'humain'}
def L(n): return f"[{n}]({ALL[n]['f']})"
def M(x): return f"{SHORT.get(x['model'],x['model'])}/{x['effort']}"
md=["""# Feuille de route (générée depuis `backlog/`)

Ordonnancement issu du **consensus avec la revue adverse** (`docs/review/CONSENSUS.md`) et de l'**intégration 2**
(`backlog/INTEGRATION-2.md`, 2026-11-18 soir). Objectif de Paul : finir le plus vite possible avec un maximum d'agents en
parallèle ; ce qui accélère passe devant (harness, dispatcher, identité, garde de fuite en S0/S1).

## Règles
1. **Étapes dans l'ordre** : MVP (S0 → S3), puis la **porte OpenChoreo** (ADR-0020), puis des **incréments** (I1 → I9) dont un
   ou deux sont ouverts à la fois. Une étape peut démarrer dès que les dépendances de ses tickets sont `done`.
2. **Dans une étape** : par vague de dépendances, d'abord les tickets `velocity`, puis ceux qui débloquent le plus.
3. **Parallélisme** : plafond de départ 4 agents (T-210), relevé par la mesure du pilote (T-322) ; au plus 2 par couloir,
   1 sur `contrat-appgen` avant T-214 ; aucun chevauchement de périmètre (T-210).
4. **Modèle** : colonne « Modèle » = `model/effort` de l'en-tête, issu de la première règle de routage qui s'applique
   (`backlog/proposals/model-routing.yaml`, ADR-0023 proposé) ; un modèle proposé ne fait que monter au-dessus du plancher.
5. **Gestes de Paul par lot** : une séance par étape (liste ci-dessous, assistant T-325). Les agents préparent les PR et les demandes exactes.
6. **MVP** = une app A sur le homelab (VM lab), en prod, livrée à partir d'une phrase, avec preuve datée sans coordinateur.
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
# Lancement 24/7
PILOT='T-322'; AFTER=['T-314','T-321','T-315','T-316','T-317','T-320','T-318','T-323']
if PILOT in T:
    md.append(f"\n## Lancement 24/7\n\nPilote de **24 h à N=3** en dispatch manuel ({L(PILOT)}) : mesure du coût par ticket, du % de quota 5 h et hebdomadaire,"
              " de la concurrence cloud ; puis N=6, puis 8-10 si le quota hebdomadaire reste sous 70 % au jour 3. Prérequis (ordre de vague) :\n")
    md.append("| Ticket | Titre | Vague | Classe | Modèle |\n|---|---|---|---|---|")
    for n in sorted(anc(PILOT)|{PILOT},key=lambda n:(T[n]['w'],n)):
        md.append(f"| {L(n)} | {T[n]['title']} | {T[n]['w']} | {T[n]['cls']} | {M(T[n])} |")
    md.append("\nAprès le pilote (cron, merge armé, ntfy, reprise, revue, trieur, travailleur homelab, tableau de bord) : "+
              ", ".join(f"{L(n)} ({T[n]['stage']})" for n in AFTER if n in T)+".")
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
open('/home/user/openchoreo-lab/backlog/ROADMAP.md','w').write('\n'.join(md)+'\n')
for st in ORDER:
    N=[n for n in T if T[n]['stage']==st]
    if N: print(st,len(N),'humains',sum(('MANDAT' in T[n]['cls'] or 'REVUE' in T[n]['cls']) for n in N),dict(collections.Counter(SHORT.get(T[n]['model'],'?') for n in N)))
print('todo',len(T),'gelés',len(G),'abandonnés',len(D))
