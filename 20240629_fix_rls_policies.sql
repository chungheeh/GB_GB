-- 기존 RLS 정책을 제거
DROP POLICY IF EXISTS "User can select their own profile" ON public.profiles;
DROP POLICY IF EXISTS "User can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "User can update their own profile" ON public.profiles;

-- 새로운 RLS 정책 생성: 모든 사용자는 모든 프로필에 접근할 수 있음
CREATE POLICY "Any authenticated user can read profiles" 
ON public.profiles 
FOR SELECT 
USING (auth.role() = 'authenticated');

CREATE POLICY "Any authenticated user can insert profiles" 
ON public.profiles 
FOR INSERT 
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Any authenticated user can update profiles" 
ON public.profiles 
FOR UPDATE 
USING (auth.role() = 'authenticated');

-- 테이블의 상태를 확인하기 위한 진단 쿼리 (참고용)
-- SELECT tablename, policyname, permissive, roles, cmd, qual, with_check 
-- FROM pg_policies 
-- WHERE tablename = 'profiles'; 