-- 프로필 테이블에 marketing_agreement 필드 추가
ALTER TABLE IF EXISTS public.profiles
ADD COLUMN IF NOT EXISTS marketing_agreement BOOLEAN DEFAULT false;

-- 설명을 추가하여 필드의 목적 명시
COMMENT ON COLUMN public.profiles.marketing_agreement IS '마케팅 서비스 이용 동의 여부';

-- 테이블의 컬럼 존재 여부를 확인하는 함수 생성
CREATE OR REPLACE FUNCTION public.check_column_exists(p_table_name text, p_column_name text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  column_exists boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = p_table_name
      AND column_name = p_column_name
  ) INTO column_exists;
  
  RETURN column_exists;
END;
$$; 