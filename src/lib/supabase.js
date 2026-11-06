import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
const url=process.env.EXPO_PUBLIC_SUPABASE_URL;
const key=process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
export const isSupabaseConfigured=Boolean(url&&key&&!url.includes('YOUR_PROJECT'));
export const supabase=createClient(url||'https://placeholder.supabase.co',key||'placeholder-anon-key',{auth:{storage:AsyncStorage,autoRefreshToken:false,persistSession:false,detectSessionInUrl:false}});
