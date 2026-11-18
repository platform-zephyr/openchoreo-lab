import re,glob,functools,sys
T={}
for f in glob.glob('/home/user/openchoreo-lab/backlog/T-*.md'):
    s=open(f).read()
    g=lambda k: re.search(rf'^{k}: (.*)$',s,re.M).group(1).strip()
    deps=[d.strip() for d in g('depends_on').strip('[]').split(',') if d.strip()]
    T[g('id')]=dict(ph=g('phase'),deps=deps,st=g('status'),v=g('velocity')=='true',lane=g('lane'),cls=g('class'),title=g('title').strip('"'))
bad=0
for i,x in T.items():
    if x['st']=='dropped': continue
    for d in x['deps']:
        if d not in T: print('MISSING',i,d); bad+=1
        elif T[d]['st']=='dropped': print('DEP-ON-DROPPED',i,d); bad+=1
        elif T[d]['ph']>x['ph']: print('PHASE',i,x['ph'],'->',d,T[d]['ph']); bad+=1
st={}
def dfs(n,path):
    global bad
    if st.get(n)==1: print('CYCLE',path+[n]); bad+=1; return
    if st.get(n)==2 or n not in T: return
    st[n]=1
    for d in T[n]['deps']: dfs(d,path+[n])
    st[n]=2
for n in T: dfs(n,[])
act={k:v for k,v in T.items() if v['st']!='dropped'}
@functools.lru_cache(None)
def L(n): return 1+max([L(d) for d in act[n]['deps'] if d in act]+[0])
print('actifs',len(act),'erreurs',bad,'profondeur',max(L(n) for n in act))
