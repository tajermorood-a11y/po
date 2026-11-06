import { supabase } from '../supabase';import { run } from './run';
export const getMatches=()=>run(()=>supabase.from('matches').select('*').order('match_date',{ascending:true}).order('id',{ascending:true}).limit(200));
export const getPredictions=(userId)=>run(()=>supabase.from('predictions').select('*').eq('user_id',userId));
export const savePrediction=(userId,matchId,home,away)=>run(()=>supabase.from('predictions').upsert({user_id:userId,match_id:matchId,predicted_home:home,predicted_away:away},{onConflict:'user_id,match_id'}).select().single());
export const getLeaderboard=()=>run(()=>supabase.from('prediction_users').select('id,display_name,username,total_points,rank,avatar_option_id').order('total_points',{ascending:false}).order('id',{ascending:true}).limit(100));
export const getAnnouncement=()=>run(()=>supabase.from('announcements').select('*').eq('is_active',true).order('id',{ascending:false}).limit(1).maybeSingle());
export const getAvatarOptions=()=>run(()=>supabase.from('avatar_options').select('*').eq('is_active',true).order('sort_order'));
