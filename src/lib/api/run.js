import { mapError } from '../errors';
export async function run(fn){try{const result=await fn();if(result?.error)return {data:null,error:mapError(result.error),raw:result.error};return {data:result?.data??result,error:null,raw:null};}catch(raw){return {data:null,error:mapError(raw),raw};}}
