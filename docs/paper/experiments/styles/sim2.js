const S=require('./sim.js'); const {W,ans,GC,AC,pat,evalAll,rngSeed,ev0,idx0,FREQ}=S; const NG=W.length;
const POLS=['analyst','maverick','detective','sweeper','wildcard','gambler'];
const RISK_GAMBLER=75, TOP=10, FRESH=4, EARLY_N=64, END_N=16, GREENS=3;
const letters=w=>new Set(w.split(''));
function greensOf(code){const g=[];for(let i=0;i<5;i++){ if(Math.floor(code/Math.pow(3,i))%3===2) g.push(i);} return g;}
function choose(pol,pool,ev,used,greens,rng,t){
  const n=pool.length, poolWords=new Set(pool.map(i=>ans[i])); const res=ev.res;
  const isEnd=n<=END_N||greens.size>=GREENS;
  const fit=r=>poolWords.has(W[r.gi]);
  const byH=(a,b)=>b.H-a.H||(fit(b)-fit(a))||FREQ.get(W[b.gi])-FREQ.get(W[a.gi]);
  const fresh=r=>[...letters(W[r.gi])].filter(c=>!used.has(c)).length;
  if(n===1) return res.find(r=>W[r.gi]===ans[pool[0]]);
  const end=pol=>{
    const kind={analyst:'probe',maverick:'close',detective:'probe',sweeper:'close',wildcard:'probe',gambler:'closeFreq'}[pol];
    if(kind==='probe'){ const c=n>=3?res.filter(r=>!fit(r)):res; return [...(c.length?c:res)].sort(byH)[0]; }
    const f=res.filter(fit); if(kind==='close') return [...f].sort(byH)[0]; return [...f].sort((a,b)=>FREQ.get(W[b.gi])-FREQ.get(W[a.gi]))[0];
  };
  // the gamblers take their risks on the first two turns, then settle, whatever the pool
  if(pol==='wildcard'||pol==='gambler'){
    if(t<2) return [...res].sort((a,b)=>b.D-a.D||byH(a,b))[0];
    if(pol==='wildcard') return [...res].sort(byH)[0];
    const f=res.filter(fit); return [...f].sort((a,b)=>FREQ.get(W[b.gi])-FREQ.get(W[a.gi]))[0];
  }
  if(isEnd) return end(pol);
  switch(pol){
    case 'analyst': case 'maverick': return [...res].sort(byH)[0];
    case 'detective': case 'sweeper': { let mx=0; for(const r of res){const f=fresh(r); if(f>mx)mx=f;} return [...res].filter(r=>fresh(r)===mx).sort((a,b)=>FREQ.get(W[b.gi])-FREQ.get(W[a.gi]))[0]; }
    case 'wildcard': case 'gambler': return [...res].sort((a,b)=>b.D-a.D||byH(a,b))[0];
  }
}
function play(pol,answerIdx,rng,keep){
  let pool=idx0, ev=ev0, used=new Set(), greens=new Set(), rows=[];
  for(let t=0;t<6;t++){
    const n=pool.length; const ch=choose(pol,pool,ev,used,greens,rng,t); const guess=W[ch.gi];
    const outcome=pat(GC[ch.gi],AC[answerIdx]); const next=pool.filter(i=>pat(GC[ch.gi],AC[i])===outcome);
    const poolWords=new Set(pool.map(i=>ans[i]));
    const rank=ev.res? ev.res.filter(r=>r.H>ch.H+1e-9).length/NG*100 : 0;
    const row={t,guess,n,H:ch.H,skill:ch.skill,risk:ch.risk,D:ch.D,rank,fresh:[...letters(guess)].filter(c=>!used.has(c)).length,fits:poolWords.has(guess),greens:greens.size,landed:next.length,win:guess===ans[answerIdx],sizes:keep?ch.sizes:null,ev:keep?ev:null,pool:keep?pool:null,Hs:ev.Hs,Ds:ev.Ds};
    const early=n>=EARLY_N, end=n<=END_N||greens.size>=GREENS;
    row.phase=n===1?'none':early?'early':end?'end':'middle';
    if(n>1){
      if(early) row.label=row.risk>=RISK_GAMBLER?'gambler':row.rank<=TOP?'maximiser':row.fresh>=FRESH?'eliminator':'none';
      else if(end) row.label=row.fits?'closer':(row.rank<=TOP&&n>=3)?'prober':'none';
      else row.label='none';
    } else row.label='none';
    rows.push(row);
    for(const c of guess) used.add(c); for(const g of greensOf(outcome)) greens.add(g);
    if(row.win) break;
    pool=next; ev=pool.length>1?evalAll(pool):{res:evalAll(pool).res,Hs:0,Ds:0,n:1};
  }
  return rows;
}
function judge(rows){
  const rate=(phase,labels)=>{const g=rows.filter(r=>r.phase===phase); if(!g.length) return {n:0,best:null,rates:{}}; const rates={}; for(const l of labels) rates[l]=g.filter(r=>r.label===l).length/g.length; const order=labels; let best=null,bv=0; for(const l of order){ if(rates[l]>bv+1e-9){bv=rates[l];best=l;} } return {n:g.length,best:bv>=0.4?best:null,rates}; };
  const e=rate('early',['gambler','maximiser','eliminator']); const d=rate('end',['closer','prober']);
  return {early:e,end:d};
}
const NAME={'maximiser|prober':'analyst','maximiser|closer':'maverick','eliminator|prober':'detective','eliminator|closer':'sweeper','gambler|prober':'wildcard','gambler|closer':'gambler'};
module.exports={play,judge,POLS,NAME,RISK_GAMBLER,TOP,FRESH,EARLY_N,END_N,GREENS};
if(require.main===module){
  const G=+process.argv[2]||30; const conf={};
  for(const pol of POLS){ const rng=rngSeed(55); conf[pol]={};
    for(let g=0;g<G;g++){ const a=Math.floor(rng()*3000); const rows=play(pol,a,rng,false); const j=judge(rows);
      const key=(j.early.best||'?')+'|'+(j.end.best||'?'); const nm=NAME[key]||key; conf[pol][nm]=(conf[pol][nm]||0)+1; }
    console.log(pol.padEnd(9),JSON.stringify(conf[pol])); }
}
