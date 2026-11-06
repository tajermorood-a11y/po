# PHANTOM (فانتوم)

تطبيق توقع نتائج كرة القدم مبني وفق ملف `PHANTOM_BUILD_PROMPT.md` باستخدام Expo SDK 52 وReact Native 0.76.3 وSupabase.

## 1) المتطلبات
- Node.js 20 LTS وnpm
- مشروع Supabase مستقل
- Expo Go المتوافق مع SDK 52 أو EAS Build

## 2) إعداد Supabase
1. أنشئ مشروعاً جديداً باسم PHANTOM.
2. افتح SQL Editor وشغّل الملف `supabase/PHANTOM_SCHEMA.sql` مرة واحدة على قاعدة بيانات فارغة.
3. انسخ Project URL ومفتاح anon/publishable إلى `.env` وفق `.env.example`. لا تستخدم `service_role` داخل التطبيق.
4. أضف المباريات وأكواد التعبئة من SQL Editor كما في القسم 12 من ملف المواصفات.

## 3) إعداد التطبيق
```bash
cp .env.example .env
# عدّل قيم EXPO_PUBLIC_SUPABASE_URL و EXPO_PUBLIC_SUPABASE_ANON_KEY
npm install
npx expo install --fix
npx expo-doctor
npx expo start
```

## 4) Android APK
```bash
npm install -g eas-cli
eas login
eas init
eas env:create --name EXPO_PUBLIC_SUPABASE_URL --value 'YOUR_URL' --environment preview
eas env:create --name EXPO_PUBLIC_SUPABASE_ANON_KEY --value 'YOUR_ANON_KEY' --environment preview
eas build -p android --profile preview
```

## 5) قبل الإنتاج
- استبدل `com.yourname.phantom` في `app.config.js` بمعرّف حزمة فريد تملكه.
- راجع سياسات RLS والصلاحيات في Appendix A قبل إطلاق التطبيق؛ الملف يتضمن سياسات عامة واسعة كما كُتبت في المواصفات، ولا ينبغي اعتبارها تدقيقاً أمنياً للإنتاج.
- لم تُضمّن بيانات اتصال فعلية لأن مشروع Supabase ومفاتيحه لم يتم إعدادهما بعد.
