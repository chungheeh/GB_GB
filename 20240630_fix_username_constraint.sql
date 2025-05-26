-- username 필드의 NOT NULL 제약 조건 제거
ALTER TABLE public.profiles 
ALTER COLUMN username DROP NOT NULL;

-- 기존 NULL 값인 username을 기본값으로 업데이트
UPDATE public.profiles
SET username = COALESCE(email, id::text, '사용자')
WHERE username IS NULL;

-- profiles 테이블의 현재 제약 조건을 확인하는 쿼리 (참고용)
-- SELECT conname, contype, pg_get_constraintdef(oid) 
-- FROM pg_constraint 
-- WHERE conrelid = 'public.profiles'::regclass;  
