import { supabase } from '../supabase';import { run } from './run';
export const register=(p)=>run(()=>supabase.rpc('phantom_register',{p_username:p.username,p_password:p.password,p_display_name:p.displayName||null}));
export const login=(p)=>run(()=>supabase.rpc('phantom_login',{p_username:p.username,p_password:p.password}));
export const updateProfile=(p)=>run(()=>supabase.rpc('update_profile',{p_user_id:p.userId,p_display_name:p.displayName,p_avatar_option_id:p.avatarOptionId}));
export const markAnnouncementSeen=(userId,id)=>run(()=>supabase.rpc('mark_announcement_seen',{p_user_id:userId,p_id:id}));
export const refreshUser=(id)=>run(()=>supabase.from('prediction_users').select('id,username,display_name,avatar_option_id,total_points,rank,last_seen_announcement_id').eq('id',id).single());
