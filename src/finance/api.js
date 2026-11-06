import {supabase} from './supabaseClient';import {run} from '../lib/api/run';
export const getAccount=(userId)=>run(()=>supabase.rpc('get_account',{p_user_id:userId}));
export const getPointsHistory=(userId)=>run(()=>supabase.rpc('get_points_history',{p_user_id:userId}));
export const getWalletHistory=(userId,limit=50)=>run(()=>supabase.rpc('get_wallet_history',{p_user_id:userId,p_limit:limit}));
export const getBadges=()=>run(()=>supabase.rpc('get_badges'));
export const redeemCode=(userId,code,referral)=>run(()=>supabase.rpc('redeem_topup_code',{p_user_id:userId,p_code:code,p_referral:referral||null}));
export const setBadge=(userId,badge)=>run(()=>supabase.rpc('set_badge',{p_user_id:userId,p_badge:badge}));
export const isNotVerifiedError=(raw)=>String(raw?.message||raw?.details||'').includes('not_verified');
