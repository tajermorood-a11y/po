export const formatMoney=(v)=>Number(v||0).toLocaleString('en-US');
export const formatDay=(v)=>String(v||'').replaceAll('-','/');
export const isMatchOpen=(m)=>m?.status==='upcoming'&&(!m.lock_time||new Date(m.lock_time).getTime()>Date.now());
export const formatDateTime=(m)=>`${formatDay(m?.match_date)}  ${m?.match_time||''}`;
export const roundPoints=(base,odds)=>{const cents=Math.round(Number(odds||1)*100);return Math.floor((base*cents+50)/100);};
export const outcome=(h,a)=>h===a?'draw':h>a?'home':'away';
export const expectedPoints=(ph,pa,odds)=>({exact:roundPoints(25,odds),outcome:roundPoints(5,odds),wrong:roundPoints(1,odds)});
