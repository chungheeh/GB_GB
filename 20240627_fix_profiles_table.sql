-- profiles 테이블이 존재하는지 확인하고, 없으면 생성
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT,
    username TEXT,
    role TEXT,
    phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 추가 필드 확인 및 추가
ALTER TABLE IF EXISTS public.profiles
ADD COLUMN IF NOT EXISTS marketing_agreement BOOLEAN DEFAULT false;

-- RLS(Row Level Security) 정책 설정
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 사용자가 자신의 프로필만 접근할 수 있도록 정책 설정
DO $$ 
BEGIN
    -- all 정책이 이미 존재하는지 확인
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'profiles' AND policyname = 'User can select their own profile'
    ) THEN
        CREATE POLICY "User can select their own profile" 
        ON public.profiles 
        FOR SELECT USING (auth.uid() = id);
    END IF;
    
    -- insert 정책이 이미 존재하는지 확인
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'profiles' AND policyname = 'User can insert their own profile'
    ) THEN
        CREATE POLICY "User can insert their own profile" 
        ON public.profiles 
        FOR INSERT WITH CHECK (auth.uid() = id);
    END IF;
    
    -- update 정책이 이미 존재하는지 확인
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'profiles' AND policyname = 'User can update their own profile'
    ) THEN
        CREATE POLICY "User can update their own profile" 
        ON public.profiles 
        FOR UPDATE USING (auth.uid() = id);
    END IF;
END $$; 