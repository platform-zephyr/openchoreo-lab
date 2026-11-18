import re,glob,functools,collections
ALL={}
for f in sorted(glob.glob('/home/user/openchoreo-lab/backlog/T-*.md')):
    s=open(f).read(); g=lambda k: re.search(rf'^{k}: (.*)$',s,re.M).group(1).strip()
    ALL[g('id')]=dict(f=f.split('/')[-1],st=g('status'),stage=g('stage'),deps=[d.strip() for d in g('depends_on').strip('[]').split(',') if d.strip()],
                    v=g('velocity')=='true',lane=g('lane'),cls=g('class'),title=g('title').strip('"'))
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
for n in T: T[n]['w']=W(n); T[n]['u']=len(desc(n))
ORDER=['S0','S1','S2','S3','PORTE','I1','I1bis','I2','I3','I4','I5','I6','I7','I8','I9']
NAMES={'S0':'MVP — socle de confiance','S1':'MVP — preuve automatique','S2':'MVP — deux moteurs en parallèle (OpenChoreo et plain)','S3':'MVP — golden path et intentions',
 'PORTE':"Porte d'adoption OpenChoreo (2026-12-04)",'I1':'Données','I1bis':'Archétypes D et E','I2':'Secrets et identité','I3':'Exposition, admission, première app familiale',
 'I4':'Exploitation : observabilité, remédiation, ntfy','I5':'Montées de version','I6':'Migration Doppler, rotation, audit','I7':'Services IA (homelab)','I8':'Mesure (DORA, maturité)','I9':'Divers'}
def L(n): return f"[{n}]({ALL[n]['f']})"
def human(x): return 'MANDAT' in x['cls'] or 'REVUE' in x['cls']
md=["""# Feuille de route (générée depuis `backlog/`)

Ordonnancement issu du **consensus avec la revue adverse** (`docs/review/CONSENSUS.md`, 2026-11-18). Objectif de Paul : finir le
plus vite possible avec un maximum d'agents en parallèle ; ce qui accélère passe devant.

## Règles
1. **Étapes dans l'ordre** : MVP (S0 → S3), puis la **porte OpenChoreo** (ADR-0020), puis des **incréments** (I1 → I8) dont un
   ou deux sont ouverts à la fois. Une étape peut démarrer dès que les dépendances de ses tickets sont `done`.
2. **Dans une étape** : par vague de dépendances, d'abord les tickets `velocity`, puis ceux qui débloquent le plus.
3. **Parallélisme** : plafond de 4 agents (abonnement, T-145) ; au plus 2 par couloir, 1 sur `contrat-appgen` avant T-214.
4. **Gestes de Paul par lot** : une fois par étape (liste ci-dessous). Les agents préparent les PR et les demandes exactes.
5. **MVP** = une app A sur le homelab, en prod, livrée à partir d'une phrase, avec preuve datée sans coordinateur.
"""]
md.append("## Gestes de Paul par étape\n")
for st in ORDER:
    H=[n for n in T if T[n]['stage']==st and human(T[n])]
    if H: md.append(f"- **{st}** : "+" ; ".join(f"{L(n)} ({T[n]['cls']})" for n in sorted(H,key=lambda n:(T[n]['w'],n))))
for st in ORDER:
    N=[n for n in T if T[n]['stage']==st]
    if not N: continue
    md.append(f"\n## {st} — {NAMES[st]} ({len(N)} tickets)\n\n| Ticket | Titre | Vague | Couloir | Classe | Vélocité | Débloque |\n|---|---|---|---|---|---|---|")
    for n in sorted(N,key=lambda n:(T[n]['w'],-T[n]['v'],-T[n]['u'],n)):
        x=T[n]; md.append(f"| {L(n)} | {x['title']} | {x['w']} | {x['lane']} | {x['cls']} | {'oui' if x['v'] else ''} | {x['u']} |")
G=[n for n,x in ALL.items() if x['st'] in ('deferred','blocked')]
md.append(f"\n## Gelés jusqu'à la porte ou bloqués par un déclencheur ({len(G)})\n")
md.append(", ".join(f"{L(n)} ({ALL[n]['st']})" for n in sorted(G)))
D=[n for n,x in ALL.items() if x['st']=='dropped']
md.append(f"\n\n## Absorbés ou supprimés ({len(D)})\n\n"+", ".join(L(n) for n in sorted(D)))
open('/home/user/openchoreo-lab/backlog/ROADMAP.md','w').write('\n'.join(md)+'\n')
for st in ORDER:
    N=[n for n in T if T[n]['stage']==st]
    if N: print(st,len(N),'humains',sum(human(T[n]) for n in N))
