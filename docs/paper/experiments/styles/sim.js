const {all,ans}=require('./words.js');
const log2=Math.log2;
const W=all.map(x=>x[0]), FREQ=new Map(all.map(x=>[x[0],x[1]]));
const code=w=>Uint8Array.from([...w].map(c=>c.charCodeAt(0)-97));
const GC=W.map(code), AC=ans.map(code);
const P3=[1,3,9,27,81];
const cnt=new Int8Array(26);
function pat(g,a){ // g,a Uint8Array(5)
  let r=0; cnt.fill(0); const m=[0,0,0,0,0];
  for(let i=0;i<5;i++){ if(g[i]===a[i]) m[i]=2; else cnt[a[i]]++; }
  for(let i=0;i<5;i++){ if(m[i]!==2 && cnt[g[i]]>0){m[i]=1;cnt[g[i]]--;} }
  for(let i=0;i<5;i++) r+=m[i]*P3[i];
  return r;
}
const NG=W.length;
// evaluate every guess against pool (array of answer indices)
function evalAll(pool){
  const n=pool.length, res=new Array(NG);
  const counts=new Int32Array(243);
  for(let gi=0;gi<NG;gi++){
    counts.fill(0); const g=GC[gi];
    for(let k=0;k<n;k++) counts[pat(g,AC[pool[k]])]++;
    let H=0, sizes=[];
    for(let c=0;c<243;c++){ const s=counts[c]; if(s){ sizes.push(s); H+=s/n*log2(n/s);} }
    let less=0,more=0;
    for(const s of sizes){ const gn=log2(n/s); if(gn<H-1e-9) less+=s; else if(gn>H+1e-9) more+=s; }
    res[gi]={gi,H,D:(less-more)/n*100,sizes};
  }
  let Hs=0,Ds=0; for(const r of res){ if(r.H>Hs)Hs=r.H; if(r.D>Ds)Ds=r.D; }
  for(const r of res){ r.skill=Hs>0?r.H/Hs*100:100; r.risk=Ds>0?Math.max(0,r.D)/Ds*100:0; }
  return {res,Hs,Ds,n};
}
const inPool=new Set(); // helper built per level
function playLevel(pool,pol,turn,rng,ev){
  const poolWords=new Set(pool.map(i=>ans[i]));
  const cand=ev.res;
  const fits=cand.filter(r=>poolWords.has(W[r.gi]));
  const byH=(a,b)=>b.H-a.H||( (poolWords.has(W[b.gi])?1:0)-(poolWords.has(W[a.gi])?1:0))||FREQ.get(W[b.gi])-FREQ.get(W[a.gi]);
  if(pool.length===1) return cand.find(r=>W[r.gi]===ans[pool[0]]);
  switch(pol){
    case 'analyst': return [...cand].sort(byH)[0];
    case 'maverick': { const top=cand.filter(r=>r.skill>=95).sort((a,b)=>b.D-a.D||byH(a,b)); return top[0]; }
    case 'steady': return [...fits].sort(byH)[0];
    case 'gambler': return [...fits].sort((a,b)=>FREQ.get(W[b.gi])-FREQ.get(W[a.gi]))[0];
    case 'wanderer': { return cand[Math.floor(rng()*cand.length)]; }
    case 'wildcard': { if(turn<2){ return [...cand].sort((a,b)=>b.D-a.D||byH(a,b))[0]; } return [...cand].sort(byH)[0]; }
  }
}
function rngSeed(s){return()=>{s=(s*1664525+1013904223)%4294967296;return s/4294967296}}
const idx0=ans.map((_,i)=>i);
const ev0=evalAll(idx0);
function playGame(pol,answerIdx,rng,keep){
  let pool=idx0, ev=ev0, rows=[];
  for(let t=0;t<6;t++){
    const ch=playLevel(pool,pol,t,rng,ev);
    const guess=W[ch.gi];
    const outcome=pat(GC[ch.gi],AC[answerIdx]);
    const next=pool.filter(i=>pat(GC[ch.gi],AC[i])===outcome);
    const landed=next.length;
    // landed outcome size = size of group of the answer
    const win=guess===ans[answerIdx];
    const row={t,guess,n:pool.length,H:ch.H,skill:ch.skill,risk:ch.risk,D:ch.D,landed,win,sizes:keep?ch.sizes:null,Hs:ev.Hs,Ds:ev.Ds,ev:keep?ev:null,pool:keep?pool:null};
    rows.push(row);
    if(win) break;
    pool=next; if(pool.length>1||t<5) ev=pool.length>1?evalAll(pool):{res:null};
    if(pool.length===1){ ev={res:evalAll(pool).res,Hs:0,Ds:0,n:1}; }
  }
  return rows;
}
module.exports={W,ans,GC,AC,pat,evalAll,playGame,rngSeed,ev0,idx0,FREQ};
if(require.main===module){
  const pols=['analyst','maverick','steady','gambler','wanderer','wildcard'];
  const GAMES=+process.argv[2]||60;
  for(const pol of pols){
    const rng=rngSeed(7); let sk=0,rk=0,cnt=0,tries=0,won=0,gs=0;
    for(let g=0;g<GAMES;g++){
      const a=Math.floor(rng()*3000);
      const rows=playGame(pol,a,rng,false);
      for(const r of rows){ if(r.n>1){sk+=r.skill;rk+=r.risk;cnt++;} }
      tries+=rows.length; if(rows[rows.length-1].win){won++;} gs++;
    }
    console.log(pol.padEnd(9),'skill',(sk/cnt).toFixed(1),'risk',(rk/cnt).toFixed(1),'tries',(tries/gs).toFixed(2),'won',won+'/'+gs);
  }
}
