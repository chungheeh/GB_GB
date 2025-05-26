# Supabase 마이그레이션 가이드

이 디렉토리에는 Supabase 데이터베이스 스키마를 관리하는 마이그레이션 파일이 포함되어 있습니다.

## 마이그레이션 실행 방법

### 옵션 1: Supabase CLI 사용 (권장)

```bash
npx supabase migration up
```

### 옵션 2: Supabase 대시보드 SQL 에디터 사용

1. [Supabase 대시보드](https://app.supabase.com/)에 로그인합니다.
2. 프로젝트를 선택합니다.
3. 왼쪽 메뉴에서 "SQL Editor"를 클릭합니다.
4. 각 마이그레이션 파일의 내용을 복사하여 에디터에 붙여넣고 실행합니다.

## 프로필 테이블 오류 해결 순서

역할 선택 페이지에서 오류가 발생하는 경우, 다음 순서대로 실행해보세요:

1. `20240627_fix_profiles_table.sql`: profiles 테이블 생성 및 구조 설정
2. `20240629_fix_rls_policies.sql`: RLS 정책 수정
3. `20240626_add_marketing_agreement.sql`: marketing_agreement 필드 추가
4. `20240628_add_sql_query_rpc.sql`: SQL 쿼리 실행 함수 추가 (개발 환경 전용)

## 역할 선택 문제 해결

역할 선택 페이지에서 계속 오류가 발생하는 경우:

1. 개발 도구의 "디버그 모드"를 활성화하세요.
2. "응급 역할 설정" 섹션에서 직접 역할을 설정해 보세요.
3. SQL 쿼리 도구를 사용하여 다음 쿼리로 테이블 상태를 확인하세요:

```sql
SELECT * FROM profiles LIMIT 10;
```

## 주의 사항

- `run_sql_query` 함수는 개발 환경에서만 사용해야 합니다. 프로덕션 환경에서는 보안상 제거해야 합니다.
- 실제 데이터가 있는 환경에서는 데이터 손실을 방지하기 위해 마이그레이션을 주의해서 실행하세요.
# genbrigde_web
