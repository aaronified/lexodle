const fs=require('fs'),path=require('path');
const lines=fs.readFileSync(path.join(__dirname,'../../../../app/assets/words/en.txt'),'utf8').split('\n');
const all=[];for(const l of lines){const [w,f]=l.trim().split(/\s+/);if(w&&/^[a-z]{5}$/.test(w))all.push([w,+f]);}
all.sort((a,b)=>b[1]-a[1]);
console.log('five-letter',all.length,'top',all.slice(0,5).map(x=>x[0]).join(','));
const ans=all.slice(0,3000).map(x=>x[0]);
console.log('prism in answers',ans.includes('prism'),'rank',all.findIndex(x=>x[0]==='prism'));
module.exports={all,ans};
