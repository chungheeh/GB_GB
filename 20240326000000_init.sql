-- 질문 테이블 생성
CREATE TABLE IF NOT EXISTS public.questions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'answered', 'completed')),
    is_ai_question BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 답변 테이블 생성
CREATE TABLE IF NOT EXISTS public.answers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    content TEXT NOT NULL,
    question_id UUID NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_selected BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- updated_at을 자동으로 업데이트하는 함수 생성
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- questions 테이블에 트리거 추가
DROP TRIGGER IF EXISTS update_questions_updated_at ON public.questions;
CREATE TRIGGER update_questions_updated_at
    BEFORE UPDATE ON public.questions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- answers 테이블에 트리거 추가
DROP TRIGGER IF EXISTS update_answers_updated_at ON public.answers;
CREATE TRIGGER update_answers_updated_at
    BEFORE UPDATE ON public.answers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS(Row Level Security) 정책 설정
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.answers ENABLE ROW LEVEL SECURITY;

-- 기존 정책들을 먼저 삭제
DROP POLICY IF EXISTS "질문 조회 정책" ON public.questions;
DROP POLICY IF EXISTS "질문 생성 정책" ON public.questions;
DROP POLICY IF EXISTS "질문 수정 정책" ON public.questions;
DROP POLICY IF EXISTS "질문 삭제 정책" ON public.questions;
DROP POLICY IF EXISTS "답변 조회 정책" ON public.answers;
DROP POLICY IF EXISTS "답변 생성 정책" ON public.answers;
DROP POLICY IF EXISTS "답변 수정 정책" ON public.answers;
DROP POLICY IF EXISTS "답변 삭제 정책" ON public.answers;

-- 질문 테이블 정책 재설정
CREATE POLICY "질문 조회 정책" ON public.questions
    FOR SELECT USING (true);

CREATE POLICY "질문 생성 정책" ON public.questions
    FOR INSERT
    WITH CHECK (true);

CREATE POLICY "질문 수정 정책" ON public.questions
    FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "질문 삭제 정책" ON public.questions
    FOR DELETE
    USING (auth.uid() = user_id);

-- 답변 테이블 정책
CREATE POLICY "답변 조회 정책" ON public.answers
    FOR SELECT USING (true);

CREATE POLICY "답변 생성 정책" ON public.answers
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "답변 수정 정책" ON public.answers
    FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "답변 삭제 정책" ON public.answers
    FOR DELETE
    USING (auth.uid() = user_id);

-- 실시간 구독을 위한 publication 생성
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE questions, answers;

-- 테이블 권한 설정
GRANT ALL ON public.questions TO authenticated;
GRANT ALL ON public.answers TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT ON public.questions TO anon;
GRANT SELECT ON public.answers TO anon;

-- 만족도 enum 타입이 없을 경우에만 생성
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'satisfaction_level') THEN
        CREATE TYPE satisfaction_level AS ENUM ('neutral', 'good', 'excellent');
    END IF;
END
$$;

-- questions 테이블에 satisfaction 컬럼 추가
ALTER TABLE questions ADD COLUMN IF NOT EXISTS satisfaction satisfaction_level; 

-- Reset and recreate public schema and profiles table
DROP SCHEMA IF EXISTS public CASCADE;

-- Create public schema
CREATE SCHEMA IF NOT EXISTS public;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create public.profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  role TEXT NOT NULL CHECK (role IN ('YOUTH', 'SENIOR')),
  username TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT username_length CHECK (char_length(username) >= 3)
);

-- Create questions table
CREATE TABLE public.questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT CHECK (category IN ('건강', '생활', '안전/응급상황', '식사/영양', '운동/재활', '여가활동', '디지털도움', '복지')) NOT NULL DEFAULT '생활',
  image_url TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'answered', 'completed')) NOT NULL,
  is_ai_question BOOLEAN DEFAULT false NOT NULL,
  satisfaction TEXT CHECK (satisfaction IN ('neutral', 'good', 'excellent')),
  answered_at TIMESTAMP WITH TIME ZONE,
  answered_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create answers table
CREATE TABLE public.answers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  question_id UUID REFERENCES public.questions(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  is_selected BOOLEAN DEFAULT false NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create RLS policies for profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Allow public read access to profiles
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

-- Allow users to insert their own profile
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Allow users to delete their own profile
CREATE POLICY "Users can delete their own profile"
  ON public.profiles FOR DELETE
  USING (auth.uid() = id);

-- Create RLS policies for questions
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Questions are viewable by everyone"
  ON public.questions FOR SELECT
  USING (true);

CREATE POLICY "Users can insert their own questions"
  ON public.questions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own questions"
  ON public.questions FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own questions"
  ON public.questions FOR DELETE
  USING (auth.uid() = user_id);

-- Create RLS policies for answers
ALTER TABLE public.answers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Answers are viewable by everyone"
  ON public.answers FOR SELECT
  USING (true);

CREATE POLICY "Users can insert their own answers"
  ON public.answers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own answers"
  ON public.answers FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own answers"
  ON public.answers FOR DELETE
  USING (auth.uid() = user_id);

-- Create profile handling function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, role, username)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    UPPER(COALESCE(NEW.raw_user_meta_data->>'role', 'YOUTH')),
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$;

-- Trigger for handling new users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Handle updated_at for all tables
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

-- Triggers for handling updated_at
DROP TRIGGER IF EXISTS set_updated_at ON public.profiles;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON public.questions;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.questions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON public.answers;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.answers
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Create indexes
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);
CREATE INDEX IF NOT EXISTS profiles_username_idx ON public.profiles(username);
CREATE INDEX IF NOT EXISTS profiles_role_idx ON public.profiles(role);
CREATE INDEX IF NOT EXISTS questions_user_id_idx ON public.questions(user_id);
CREATE INDEX IF NOT EXISTS questions_status_idx ON public.questions(status);
CREATE INDEX IF NOT EXISTS questions_category_idx ON public.questions(category);
CREATE INDEX IF NOT EXISTS answers_question_id_idx ON public.answers(question_id);
CREATE INDEX IF NOT EXISTS answers_user_id_idx ON public.answers(user_id);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO postgres, service_role;

-- Grant specific access to authenticated users
GRANT SELECT ON public.profiles TO anon, authenticated;
GRANT INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.questions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.answers TO authenticated;

-- Grant usage on uuid-ossp functions
GRANT EXECUTE ON FUNCTION uuid_generate_v4() TO authenticated;

-- Create a new storage bucket for public images if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM storage.buckets
        WHERE id = 'public'
    ) THEN
        INSERT INTO storage.buckets (id, name, public)
        VALUES ('public', 'public', true);
    END IF;
END $$;

-- Set up storage policy to allow authenticated uploads
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE tablename = 'objects'
        AND policyname = 'Allow authenticated uploads'
    ) THEN
        CREATE policy "Allow authenticated uploads"
        ON storage.objects
        FOR insert
        TO authenticated
        WITH check (
            bucket_id = 'public' AND
            (storage.foldername(name))[1] = 'question-images'
        );
    END IF;
END $$;

-- Set up storage policy to allow public access
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE tablename = 'objects'
        AND policyname = 'Allow public access'
    ) THEN
        CREATE policy "Allow public access"
        ON storage.objects
        FOR select
        TO public
        USING (bucket_id = 'public');
    END IF;
END $$; 

-- Add answered_at and answered_by columns to questions table
ALTER TABLE public.questions
  ADD COLUMN IF NOT EXISTS answered_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS answered_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Create index for answered_by column
CREATE INDEX IF NOT EXISTS questions_answered_by_idx ON public.questions(answered_by);

-- Update RLS policies for questions table
DROP POLICY IF EXISTS "질문 수정 정책" ON public.questions;
CREATE POLICY "질문 수정 정책" ON public.questions
    FOR UPDATE
    USING (
      auth.uid() = user_id OR 
      (auth.uid() = answered_by AND status = 'answered')
    );

-- Create answers table if not exists
CREATE TABLE IF NOT EXISTS public.answers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    question_id UUID REFERENCES public.questions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    is_selected BOOLEAN DEFAULT false NOT NULL
);

-- Create ai_answers table if not exists
CREATE TABLE IF NOT EXISTS public.ai_answers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    question_id UUID REFERENCES public.questions(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes for answers table
CREATE INDEX IF NOT EXISTS answers_question_id_idx ON public.answers(question_id);
CREATE INDEX IF NOT EXISTS answers_user_id_idx ON public.answers(user_id);

-- Create indexes for ai_answers table
CREATE INDEX IF NOT EXISTS ai_answers_question_id_idx ON public.ai_answers(question_id);

-- Enable RLS for answers table
ALTER TABLE public.answers ENABLE ROW LEVEL SECURITY;

-- Enable RLS for ai_answers table
ALTER TABLE public.ai_answers ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for answers table
DROP POLICY IF EXISTS "답변 조회 정책" ON public.answers;
CREATE POLICY "답변 조회 정책" ON public.answers
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.questions
            WHERE id = answers.question_id
            AND NOT is_ai_question
        )
    );

DROP POLICY IF EXISTS "답변 생성 정책" ON public.answers;
CREATE POLICY "답변 생성 정책" ON public.answers
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.questions
            WHERE id = question_id
            AND status = 'pending'
            AND user_id != auth.uid()
            AND NOT is_ai_question
        )
    );

DROP POLICY IF EXISTS "답변 수정 정책" ON public.answers;
CREATE POLICY "답변 수정 정책" ON public.answers
    FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "답변 삭제 정책" ON public.answers;
CREATE POLICY "답변 삭제 정책" ON public.answers
    FOR DELETE
    USING (auth.uid() = user_id);

-- Create RLS policies for ai_answers table
DROP POLICY IF EXISTS "AI 답변 조회 정책" ON public.ai_answers;
CREATE POLICY "AI 답변 조회 정책" ON public.ai_answers
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.questions
            WHERE id = ai_answers.question_id
            AND is_ai_question
        )
    );

DROP POLICY IF EXISTS "AI 답변 생성 정책" ON public.ai_answers;
CREATE POLICY "AI 답변 생성 정책" ON public.ai_answers
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.questions
            WHERE id = question_id
            AND is_ai_question
        )
    );

-- Create trigger for updating updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS answers_updated_at ON public.answers;
CREATE TRIGGER answers_updated_at
    BEFORE UPDATE ON public.answers
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS ai_answers_updated_at ON public.ai_answers;
CREATE TRIGGER ai_answers_updated_at
    BEFORE UPDATE ON public.ai_answers
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at(); 

    -- 기존 정책 삭제
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.answers;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.questions;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.ai_answers;
DROP POLICY IF EXISTS "청년 사용자 답변 등록 허용" ON public.answers;
DROP POLICY IF EXISTS "모든 사용자 답변 조회 허용" ON public.answers;
DROP POLICY IF EXISTS "답변 등록 시 질문 상태 업데이트 허용" ON public.questions;
DROP POLICY IF EXISTS "모든 사용자 질문 조회 허용" ON public.questions;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.ai_answers;
DROP POLICY IF EXISTS "Enable select for authenticated users" ON public.ai_answers;

-- 기존 함수 삭제
DROP FUNCTION IF EXISTS public.submit_answer(UUID, UUID, TEXT);

-- submit_answer 함수 재생성
CREATE OR REPLACE FUNCTION public.submit_answer(
  p_question_id UUID,
  p_user_id UUID,
  p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_user_role TEXT;
  v_answer_id UUID;
BEGIN
  -- 사용자 권한 확인
  SELECT LOWER(role) INTO v_user_role
  FROM public.profiles
  WHERE id = p_user_id;

  -- 디버그 로그
  RAISE NOTICE 'Checking user role - User ID: %, Role: %', p_user_id, v_user_role;
  
  IF v_user_role IS NULL THEN
    RAISE EXCEPTION '사용자 프로필을 찾을 수 없습니다.'
      USING ERRCODE = 'AUTH001';
  END IF;

  IF v_user_role NOT IN ('youth', 'young') THEN
    RAISE EXCEPTION '청년 사용자만 답변할 수 있습니다. (현재 역할: %)', v_user_role
      USING ERRCODE = 'AUTH002';
  END IF;

  -- 질문 상태 확인
  IF NOT EXISTS (
    SELECT 1 FROM public.questions 
    WHERE id = p_question_id 
    AND status = 'pending'
  ) THEN
    RAISE EXCEPTION '질문이 존재하지 않거나 이미 답변이 완료되었습니다.'
      USING ERRCODE = 'QUEST001';
  END IF;

  -- 답변 등록
  INSERT INTO public.answers (
    id,
    question_id,
    user_id,
    content,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    p_question_id,
    p_user_id,
    p_content,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_answer_id;

  -- 질문 상태 업데이트
  UPDATE public.questions
  SET 
    status = 'answered',
    answered_at = NOW(),
    answered_by = p_user_id,
    updated_at = NOW()
  WHERE id = p_question_id;

  -- 결과 생성
  SELECT jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'answer_id', v_answer_id,
      'question_id', p_question_id,
      'user_id', p_user_id,
      'user_role', v_user_role
    ),
    'message', '답변이 성공적으로 등록되었습니다.'
  ) INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    -- 오류 발생 시 오류 정보 반환
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'error_code', SQLSTATE,
      'debug', jsonb_build_object(
        'user_id', p_user_id,
        'user_role', v_user_role,
        'question_id', p_question_id
      )
    );
END;
$$;

-- RLS 활성화
ALTER TABLE public.answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_answers ENABLE ROW LEVEL SECURITY;

-- answers 테이블 정책
CREATE POLICY "answers_authenticated_access" ON public.answers
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- questions 테이블 정책
CREATE POLICY "questions_authenticated_access" ON public.questions
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- AI answers 테이블 정책
CREATE POLICY "ai_answers_authenticated_access" ON public.ai_answers
  FOR ALL TO authenticated
  USING (true)
  WITH CHECK (true);

-- 기본 권한 설정
ALTER TABLE public.answers FORCE ROW LEVEL SECURITY;
ALTER TABLE public.questions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.ai_answers FORCE ROW LEVEL SECURITY;

-- 권한 부여
GRANT ALL ON public.answers TO authenticated;
GRANT ALL ON public.questions TO authenticated;
GRANT ALL ON public.ai_answers TO authenticated;

-- RPC 함수 권한
GRANT EXECUTE ON FUNCTION public.submit_answer(UUID, UUID, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.submit_answer(UUID, UUID, TEXT) FROM anon; 

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid REFERENCES auth.users(id) PRIMARY KEY,
    email text,
    name text,
    username text,
    role text CHECK (role IN ('YOUTH', 'SENIOR')),
    points integer DEFAULT 0,
    profile_image text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- Set up Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- Create policies
CREATE POLICY "Public profiles are viewable by everyone"
    ON public.profiles FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- Create function to handle user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, name, username, role, points, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'role', 'YOUTH'),
        0,
        NOW(),
        NOW()
    );
    RETURN NEW;
END;
$$;

-- Create trigger for new user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user(); 
    