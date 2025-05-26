-- 이메일 인증 코드 테이블 생성
CREATE TABLE IF NOT EXISTS public.verification_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (timezone('utc'::text, now()) + interval '2 minutes') NOT NULL,
  is_used BOOLEAN DEFAULT false,
  verified BOOLEAN DEFAULT false
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS verification_codes_email_idx ON public.verification_codes(email);
CREATE INDEX IF NOT EXISTS verification_codes_code_idx ON public.verification_codes(code);

-- 이메일 인증 코드 생성 함수
CREATE OR REPLACE FUNCTION public.generate_email_verification_code(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
  v_id UUID;
  v_result JSONB;
BEGIN
  -- 이미 가입된 이메일인지 확인
  IF EXISTS (
    SELECT 1 FROM auth.users WHERE email = p_email
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '이미 가입된 이메일입니다.',
      'error_code', 'EMAIL_EXISTS'
    );
  END IF;
  
  -- 무작위 6자리 코드 생성
  v_code := lpad((floor(random() * 1000000))::text, 6, '0');
  
  -- 기존 코드 만료 처리
  UPDATE public.verification_codes
  SET is_used = true
  WHERE email = p_email AND NOT is_used;
  
  -- 새 코드 생성
  INSERT INTO public.verification_codes (
    email, 
    code, 
    created_at, 
    expires_at
  ) VALUES (
    p_email,
    v_code,
    timezone('utc'::text, now()),
    timezone('utc'::text, now()) + interval '2 minutes'
  )
  RETURNING id INTO v_id;
  
  -- 결과 생성
  SELECT jsonb_build_object(
    'success', true,
    'email', p_email,
    'code', v_code,
    'expires_at', (timezone('utc'::text, now()) + interval '2 minutes')
  ) INTO v_result;
  
  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    -- 오류 발생 시 오류 정보 반환
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'error_code', SQLSTATE
    );
END;
$$;

-- 이메일 인증 코드 검증 함수
CREATE OR REPLACE FUNCTION public.verify_email_code(p_email TEXT, p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
  v_code_exists BOOLEAN;
  v_code_valid BOOLEAN;
BEGIN
  -- 코드 유효성 검증
  SELECT 
    EXISTS (
      SELECT 1 
      FROM public.verification_codes 
      WHERE email = p_email 
      AND code = p_code 
      AND NOT is_used
      AND verified = false
    ),
    EXISTS (
      SELECT 1 
      FROM public.verification_codes 
      WHERE email = p_email 
      AND code = p_code 
      AND NOT is_used
      AND verified = false
      AND expires_at > timezone('utc'::text, now())
    )
  INTO v_code_exists, v_code_valid;
  
  -- 코드가 존재하지 않는 경우
  IF NOT v_code_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '유효하지 않은 인증 코드입니다.',
      'error_code', 'INVALID_CODE'
    );
  END IF;
  
  -- 코드가 만료된 경우
  IF NOT v_code_valid THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', '인증 코드가 만료되었습니다.',
      'error_code', 'EXPIRED_CODE'
    );
  END IF;
  
  -- 인증 코드 사용 처리
  UPDATE public.verification_codes
  SET 
    is_used = true,
    verified = true
  WHERE email = p_email 
  AND code = p_code 
  AND NOT is_used;
  
  -- 결과 생성
  SELECT jsonb_build_object(
    'success', true,
    'message', '이메일 인증이 완료되었습니다.'
  ) INTO v_result;
  
  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    -- 오류 발생 시 오류 정보 반환
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'error_code', SQLSTATE
    );
END;
$$;

-- 만료된 인증 코드 삭제 함수
CREATE OR REPLACE FUNCTION public.delete_expired_verification_codes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.verification_codes
  WHERE expires_at < timezone('utc'::text, now()) OR is_used = true;
END;
$$;

-- RLS 설정
ALTER TABLE public.verification_codes ENABLE ROW LEVEL SECURITY;

-- 인증 코드 접근 정책
CREATE POLICY "인증 코드 접근 정책" ON public.verification_codes
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 권한 부여
GRANT EXECUTE ON FUNCTION public.generate_email_verification_code(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_email_code(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_expired_verification_codes() TO service_role; 