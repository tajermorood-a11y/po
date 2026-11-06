import { supabase } from '../supabase';import { run } from './run';
export const getChallenges=(userId)=>run(()=>supabase.from('friend_challenges').select('id, friend:prediction_users!friend_challenges_friend_id_fkey(id, display_name, username, total_points, rank, avatar_option_id)').eq('user_id',userId).order('created_at',{ascending:false}));
export const findUser=(username)=>run(()=>supabase.from('prediction_users').select('id,username,display_name,total_points,rank,avatar_option_id').eq('username',username.toLowerCase()).maybeSingle());
export const addChallenge=(userId,friendId)=>run(()=>supabase.from('friend_challenges').insert({user_id:userId,friend_id:friendId}).select().single());
export const removeChallenge=(id)=>run(()=>supabase.from('friend_challenges').delete().eq('id',id));
