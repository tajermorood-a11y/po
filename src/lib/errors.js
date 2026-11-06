import { S } from '../constants/strings';
export function mapError(raw){const m=String(raw?.message||raw?.details||raw||'');if(m.includes('not_verified'))return S.gateText;if(m.includes('match_locked'))return S.closed;if(m.includes('Network request failed')||m.includes('fetch'))return S.offline;if(m.includes('duplicate key'))return S.duplicate;return S.error;}
export function errorCode(raw){return String(raw?.message||raw?.details||'');}
