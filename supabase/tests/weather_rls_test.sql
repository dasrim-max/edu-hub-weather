-- 날씨 게임 RLS 시험. 마이그레이션(20261116090000_weather_game.sql)이 적용된 뒤 실행한다.
-- 한 트랜잭션 안에서 실행하고 마지막에 롤백한다 → 가짜 데이터는 남지 않음.
begin;
set local search_path = public;
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('aaaaaaa1-1111-4111-8111-111111111111','00000000-0000-0000-0000-000000000000','authenticated','authenticated','wadmin@test.invalid','{"provider":"kakao"}','{"name":"관리자"}',now(),now()),
       ('bbbbbbb2-2222-4222-8222-222222222222','00000000-0000-0000-0000-000000000000','authenticated','authenticated','wt1@test.invalid','{"provider":"kakao"}','{"name":"교사B"}',now(),now()),
       ('ccccccc3-3333-4333-8333-333333333333','00000000-0000-0000-0000-000000000000','authenticated','authenticated','wt2@test.invalid','{"provider":"kakao"}','{"name":"교사C"}',now(),now()),
       ('ddddddd4-4444-4444-8444-444444444444','00000000-0000-0000-0000-000000000000','authenticated','authenticated','wt3@test.invalid','{"provider":"kakao"}','{"name":"미인증"}',now(),now());
update profiles set teacher_status='verified', role='admin' where id='aaaaaaa1-1111-4111-8111-111111111111';
update profiles set teacher_status='verified' where id in ('bbbbbbb2-2222-4222-8222-222222222222','ccccccc3-3333-4333-8333-333333333333');
insert into students (id, teacher_id, grade, class_no, name) values
  ('b0000001-0000-4000-8000-000000000001','bbbbbbb2-2222-4222-8222-222222222222',3,2,'가짜학생1'),
  ('c0000001-0000-4000-8000-000000000001','ccccccc3-3333-4333-8333-333333333333',5,1,'가짜학생2');
insert into weather_mission_sets (id, owner_id, name, missions, is_published) values
  ('5e700001-0000-4000-8000-000000000001','aaaaaaa1-1111-4111-8111-111111111111','공개세트','[{"t":"rain"}]',true),
  ('5e700002-0000-4000-8000-000000000002','aaaaaaa1-1111-4111-8111-111111111111','비공개세트','[{"t":"sunny"}]',false);
insert into weather_records (rid, teacher_id, student_id, content_id, mode, set_name, score, max_score, stages) values
  ('00000000-0000-4000-8000-0000000000a1','bbbbbbb2-2222-4222-8222-222222222222','b0000001-0000-4000-8000-000000000001','5e700001-0000-4000-8000-000000000001','mission','공개세트',10,10,1),
  ('00000000-0000-4000-8000-0000000000a2','ccccccc3-3333-4333-8333-333333333333','c0000001-0000-4000-8000-000000000001','5e700001-0000-4000-8000-000000000001','mission','공개세트',10,10,1);

create temp table r (n int generated always as identity, name text, pass bool) on commit drop;
grant all on r to authenticated, anon; grant usage, select on sequence r_n_seq to authenticated, anon;

-- 교사B(인증)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"bbbbbbb2-2222-4222-8222-222222222222","role":"authenticated"}', true);
insert into r(name,pass) select '교사B: 공개 세트만 보임(1개)', (select count(*) from weather_mission_sets)=1 and exists(select 1 from weather_mission_sets where name='공개세트');
do $$ begin
  begin insert into weather_mission_sets(owner_id,name,missions) values('bbbbbbb2-2222-4222-8222-222222222222','침입','[{"t":"rain"}]');
        insert into r(name,pass) values('교사B: 미션 세트 만들기 거부', false);
  exception when others then insert into r(name,pass) values('교사B: 미션 세트 만들기 거부', true); end;
end $$;
do $$ declare c int; begin
  update weather_mission_sets set name='변조' where name='공개세트'; get diagnostics c = row_count;
  insert into r(name,pass) values('교사B: 세트 수정 0건', c=0);
  delete from weather_mission_sets where name='공개세트'; get diagnostics c = row_count;
  insert into r(name,pass) values('교사B: 세트 삭제 0건', c=0);
end $$;
insert into r(name,pass) select '교사B: 기록은 자기 학생 것만(1건)', (select count(*) from weather_records)=1 and (select student_id from weather_records)='b0000001-0000-4000-8000-000000000001';
do $$ begin
  begin insert into weather_records(rid,teacher_id,student_id,content_id,mode,score,max_score,stages) values(gen_random_uuid(),'bbbbbbb2-2222-4222-8222-222222222222','b0000001-0000-4000-8000-000000000001','5e700001-0000-4000-8000-000000000001','mission',10,10,1);
        insert into r(name,pass) values('교사B: 기록 직접 쓰기 거부(서버 함수만)', false);
  exception when others then insert into r(name,pass) values('교사B: 기록 직접 쓰기 거부(서버 함수만)', true); end;
end $$;
do $$ declare c int; begin
  update weather_records set score=0; get diagnostics c = row_count;
  insert into r(name,pass) values('교사B: 기록 수정 거부(0건)', c=0);
exception when others then insert into r(name,pass) values('교사B: 기록 수정 거부(0건)', true);
end $$;
do $$ declare c int; begin
  delete from weather_records where rid='00000000-0000-4000-8000-0000000000a2'; get diagnostics c = row_count;
  insert into r(name,pass) values('교사B: 남의 학생 기록 삭제 0건', c=0);
  delete from weather_records where rid='00000000-0000-4000-8000-0000000000a1'; get diagnostics c = row_count;
  insert into r(name,pass) values('교사B: 자기 학생 기록 삭제 1건', c=1);
end $$;

-- 관리자
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaa1-1111-4111-8111-111111111111","role":"authenticated"}', true);
insert into r(name,pass) select '관리자: 세트 둘 다 보임', (select count(*) from weather_mission_sets)=2;
do $$ declare c int; begin
  update weather_mission_sets set is_published=true where name='비공개세트'; get diagnostics c = row_count;
  insert into r(name,pass) values('관리자: 세트 수정 1건', c=1);
  insert into weather_mission_sets(owner_id,name,missions) values('aaaaaaa1-1111-4111-8111-111111111111','새세트','[{"t":"snow"}]');
  insert into r(name,pass) values('관리자: 세트 만들기', true);
exception when others then insert into r(name,pass) values('관리자: 세트 수정·만들기', false);
end $$;
do $$ begin
  begin insert into weather_mission_sets(owner_id,name,missions) values('aaaaaaa1-1111-4111-8111-111111111111','','[{"t":"x"}]');
        insert into r(name,pass) values('관리자: 빈 이름 거부', false);
  exception when others then insert into r(name,pass) values('관리자: 빈 이름 거부', true); end;
end $$;
do $$ begin
  begin insert into weather_mission_sets(owner_id,name,missions) values('aaaaaaa1-1111-4111-8111-111111111111','빈목록','[]');
        insert into r(name,pass) values('관리자: 빈 미션 목록 거부', false);
  exception when others then insert into r(name,pass) values('관리자: 빈 미션 목록 거부', true); end;
end $$;

-- 로그인하지 않은 사용자(학생 브라우저)
reset role; set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
insert into r(name,pass) select 'anon: 세트·기록 접근 불가', not has_table_privilege('weather_mission_sets','select') and not has_table_privilege('weather_records','select')
  and not has_table_privilege('weather_records','insert') and not has_table_privilege('weather_records','delete');

-- 미인증 교사
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"ddddddd4-4444-4444-8444-444444444444","role":"authenticated"}', true);
insert into r(name,pass) select '미인증 교사: 세트 0개, 기록 0건', (select count(*) from weather_mission_sets)=0 and (select count(*) from weather_records)=0;

-- 제약(서버 함수가 쓰는 경로, 관리 권한)
reset role;
do $$ begin
  begin insert into weather_records(rid,teacher_id,student_id,content_id,mode,score,max_score,stages) values(gen_random_uuid(),'ccccccc3-3333-4333-8333-333333333333','c0000001-0000-4000-8000-000000000001','5e700001-0000-4000-8000-000000000001','mission',11,10,1);
        insert into r(name,pass) values('점수가 만점보다 큰 기록 거부', false);
  exception when check_violation then insert into r(name,pass) values('점수가 만점보다 큰 기록 거부', true); end;
end $$;
do $$ begin
  begin insert into weather_records(rid,teacher_id,student_id,content_id,mode,score,max_score,stages) values('00000000-0000-4000-8000-0000000000a2','ccccccc3-3333-4333-8333-333333333333','c0000001-0000-4000-8000-000000000001','5e700001-0000-4000-8000-000000000001','mission',10,10,1);
        insert into r(name,pass) values('같은 rid 중복 저장 거부', false);
  exception when unique_violation then insert into r(name,pass) values('같은 rid 중복 저장 거부', true); end;
end $$;
delete from students where id='c0000001-0000-4000-8000-000000000001';
insert into r(name,pass) select '학생 삭제하면 그 기록도 지워짐', not exists(select 1 from weather_records where student_id='c0000001-0000-4000-8000-000000000001');
insert into r(name,pass) select '포털에 weather 앱 등록', exists(select 1 from apps where slug='weather' and url='/games/weather/' and category='game');

select n, name, case when pass then 'PASS' else 'FAIL' end as result from r order by n;
rollback;
