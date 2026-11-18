import re,glob,functools,collections
T={}
for f in sorted(glob.glob('/home/user/openchoreo-lab/backlog/T-*.md')):
    s=open(f).read(); g=lambda k: re.search(rf'^{k}: (.*)$',s,re.M).group(1).strip()
    if g('status')=='dropped': continue
    T[g('id')]=dict(f=f.split('/')[-1],ph=g('phase'),deps=[d.strip() for d in g('depends_on').strip('[]').split(',') if d.strip()],
                    v=g('velocity')=='true',lane=g('lane'),cls=g('class'),title=g('title').strip('"'))
@functools.lru_cache(None)
def W(n): return max([W(d)+1 for d in T[n]['deps']]+[0])
children=collections.defaultdict(set)
for n,x in T.items():
    for d in x['deps']: children[d].add(n)
@functools.lru_cache(None)
def desc(n):
    r=set(children[n])
    for c in children[n]: r|=desc(c)
    return frozenset(r)
@functools.lru_cache(None)
def tail(n): return 1+max([tail(c) for c in children[n]]+[0])
for n in T: T[n]['w']=W(n); T[n]['unlock']=len(desc(n)); T[n]['tail']=tail(n)
crit=[n for n in T if T[n]['w']+T[n]['tail']==max(T[m]['w']+T[m]['tail'] for m in T)]
waves=collections.defaultdict(list)
for n,x in T.items(): waves[x['w']].append(n)
def human(x): return 'MANDAT' in x['cls'] or 'REVUE' in x['cls']
out=[]
for w in sorted(waves):
    L=sorted(waves[w],key=lambda n:(-T[n]['v'],-(n in crit),-T[n]['unlock'],n))
    lanes=collections.Counter(T[n]['lane'] for n in L)
    out.append((w,L,lanes))
import json
json.dump({'crit':sorted(crit,key=lambda n:T[n]['w']),'waves':{w:L for w,L,_ in out}},open('/tmp/roadmap.json','w'))
for w,L,lanes in out:
    print(f"VAGUE {w}: {len(L)} tickets, humains {sum(human(T[n]) for n in L)}, couloirs max {lanes.most_common(1)}")
    for n in L[:40]: print('  ',n,('V' if T[n]['v'] else ' '),('C' if n in crit else ' '),f"u{T[n]['unlock']:<3}",T[n]['lane'][:14].ljust(14),T[n]['cls'][:22].ljust(22),T[n]['title'][:60])
print('critique:',' -> '.join(sorted(crit,key=lambda n:T[n]['w'])))

# ---- écriture de backlog/ROADMAP.md ----
def link(n): return f"[{n}]({T[n]['f']})"
md=[]
md.append("""# Feuille de route (générée depuis `backlog/`)

Ordonnancement du 2026-11-18. **Objectif de Paul : finir le plus vite possible, avec un maximum d'agents en parallèle ; tout
ticket qui accélère les suivants passe devant.** Ce fichier est régénéré à partir des en-têtes des tickets.

## Stratégie
1. **Vagues** : un ticket est dans la vague *n* si sa plus longue chaîne de dépendances fait *n*. Tous les tickets d'une vague
   peuvent avancer en parallèle dès que la vague précédente est terminée (en pratique : dès que **leurs** dépendances le sont).
2. **Priorité dans une vague** : d'abord les tickets `velocity` (outillage, CI, preuve, contexte, dispatch), puis ceux qui
   débloquent le plus de tickets (`débloque`).
3. **Couloirs** : un couloir = une zone de fichiers. Au plus **2 agents par couloir** en même temps (1 pour `contrat-appgen`,
   point chaud de conflits) ; nombre total d'agents borné par le plafond LLM (T-145) et 4 jobs parallèles par défaut sur
   l'abonnement.
4. **Gestes humains en lot** : les tickets REVUE/MANDAT attendent Paul. Pour ne pas bloquer les agents, Paul traite ses gestes
   **par lot, une fois par vague** (liste ci-dessous) ; les agents préparent tout le reste (PR prêtes, demande exacte sans valeur).
5. **Le premier accélérateur est le dispatcher (T-210)** : sans lui, chaque lancement d'agent attend un humain.
""")
md.append("## Top accélérateurs\n\n| Ticket | Titre | Vague | Débloque |\n|---|---|---|---|")
for n in sorted([n for n in T if T[n]['v']],key=lambda n:(T[n]['w'],-T[n]['unlock']))[:20]:
    md.append(f"| {link(n)} | {T[n]['title']} | {T[n]['w']} | {T[n]['unlock']} |")
md.append("\n## Gestes de Paul par vague (MANDAT = geste ; REVUE = approbation de PR)\n")
for w,L,_ in out:
    H=[n for n in L if human(T[n])]
    if not H: continue
    md.append(f"- **Vague {w}** : " + " ; ".join(f"{link(n)} ({T[n]['cls']})" for n in H))
for w,L,lanes in out:
    md.append(f"\n## Vague {w} — {len(L)} tickets, {len(lanes)} couloirs\n\n| Ticket | Titre | Couloir | Classe | Vélocité | Débloque |\n|---|---|---|---|---|---|")
    for n in L:
        md.append(f"| {link(n)} | {T[n]['title']} | {T[n]['lane']} | {T[n]['cls']} | {'oui' if T[n]['v'] else ''} | {T[n]['unlock']} |")
open('/home/user/openchoreo-lab/backlog/ROADMAP.md','w').write('\n'.join(md)+'\n')
