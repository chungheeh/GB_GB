-- 개발 환경에서만 사용할 SQL 쿼리 실행 함수
-- 주의: 이 함수는 개발 환경에서만 사용해야 합니다.
CREATE OR REPLACE FUNCTION public.run_sql_query(query text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  -- 쿼리 실행 및 결과를 JSON으로 반환
  EXECUTE 'WITH query_result AS (' || query || ') SELECT to_jsonb(array_agg(row_to_json(query_result))) FROM query_result' INTO result;
  RETURN COALESCE(result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'error', SQLERRM,
    'code', SQLSTATE,
    'query', query
  );
END;
$$;

-- RPC 함수의 접근 정책 설정
ALTER FUNCTION public.run_sql_query(query text) SET search_path = public;

-- 함수에 대한 코멘트 추가
COMMENT ON FUNCTION public.run_sql_query IS '개발 환경에서만 사용해야 하는, SQL 쿼리를 직접 실행할 수 있는 함수입니다. 프로덕션 환경에서는 보안상 이 함수를 제거해야 합니다.';

-- 현재 profiles 테이블의 스키마 정보를 출력하는 SQL 코드 (참고용)
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'profiles'
-- ORDER BY ordinal_position; 