-- Run as the migration owner against a fresh test/staging project.
-- Every fixture is rolled back. No emails, persisted users or charges are created.
begin;
do $$
declare staff_user uuid:=gen_random_uuid();prefect_user uuid:=gen_random_uuid();staff_id uuid:=gen_random_uuid();prefect_id uuid:=gen_random_uuid();student_id uuid:=gen_random_uuid();product_id uuid:=gen_random_uuid();device_id uuid:=gen_random_uuid();shift_id uuid:=gen_random_uuid();sale_id uuid:=gen_random_uuid();void_id uuid:=gen_random_uuid();original jsonb;payload jsonb;blocked boolean;qty bigint;n bigint;
begin
 insert into auth.users(id,aud,role) values(staff_user,'authenticated','authenticated'),(prefect_user,'authenticated','authenticated');
 insert into public.operators(id,auth_user_id,name,role) values(staff_id,staff_user,'Test staff','staff'),(prefect_id,prefect_user,'Test prefect','prefect');
 insert into public.students(id,student_number,first_name,last_name) values(student_id,'TEST-'||student_id,'Test','Student');
 insert into public.products(id,name,category,price_cents) values(product_id,'Test item','Snacks',250);
 insert into public.price_history(product_id,price_cents,product_name,effective_from,changed_by) values(product_id,250,'Test item',now()-interval '1 day',staff_id);
 insert into public.stock_movements(product_id,quantity_delta,movement_type,operator_id) values(product_id,10,'delivery',staff_id);
 if has_table_privilege('anon','public.students','select') then raise exception 'Anonymous roster privilege';end if;
 if has_table_privilege('authenticated','public.transactions','insert') then raise exception 'Direct ledger insert allowed';end if;
 if has_table_privilege('authenticated','private.operator_pins','select') then raise exception 'PIN verifier exposed';end if;
 if has_function_privilege('anon','public.ingest_sale(jsonb)','execute') then raise exception 'Anonymous sale RPC allowed';end if;
 perform set_config('request.jwt.claim.sub',staff_user::text,true);
 execute 'set local role authenticated';
 perform public.open_shift(shift_id,now()-interval '1 hour',device_id);
 perform public.open_shift(shift_id,now()-interval '1 hour',device_id);
 payload:=jsonb_build_object('id',sale_id,'student_id',student_id,'operator_id',staff_id,'shift_id',shift_id,'device_id',device_id,'occurred_at',now(),'total_cents',500,'items',jsonb_build_array(jsonb_build_object('product_id',product_id,'product_name','Test item','quantity',2,'unit_price_cents',250,'line_total_cents',500)));
 perform public.ingest_sale(payload);perform public.ingest_sale(payload);
 select qty_on_hand into qty from public.current_stock where id=product_id;
 if qty<>8 then raise exception 'Duplicate sale or wrong stock: %',qty;end if;
 select count(*) into n from public.transactions;
 if n<>0 then raise exception 'Financial rows leaked outside logged staff RPC';end if;
 select to_jsonb(t) into original from public.staff_transactions() t where id=sale_id;
 if original is null or (original->>'total_cents')::int<>500 then raise exception 'Missing receipt';end if;
 blocked:=false;begin perform public.ingest_sale(jsonb_set(payload,'{total_cents}','1'));exception when others then blocked:=true;end;if not blocked then raise exception 'Changed UUID payload accepted';end if;
 blocked:=false;begin perform public.ingest_sale(jsonb_set(jsonb_set(payload,'{id}',to_jsonb(gen_random_uuid())),'{items}','[]'));exception when others then blocked:=true;end;if not blocked then raise exception 'Empty sale accepted';end if;
 perform set_config('request.jwt.claim.sub',prefect_user::text,true);
 blocked:=false;begin perform public.staff_transactions();exception when others then blocked:=true;end;if not blocked then raise exception 'Prefect accessed report';end if;
 blocked:=false;begin perform public.void_sale(void_id,sale_id,shift_id,'Unauthorized');exception when others then blocked:=true;end;if not blocked then raise exception 'Prefect voided sale';end if;
 blocked:=false;begin perform public.ingest_sale(payload);exception when others then blocked:=true;end;if not blocked then raise exception 'Actor spoof accepted';end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 select count(*) into n from public.students;if n<>0 then raise exception 'Unprovisioned user saw roster';end if;
 perform set_config('request.jwt.claim.sub',staff_user::text,true);
 perform public.void_sale(void_id,sale_id,shift_id,'Test reversal');perform public.void_sale(void_id,sale_id,shift_id,'Test reversal');
 select qty_on_hand into qty from public.current_stock where id=product_id;if qty<>10 then raise exception 'Void stock wrong';end if;
 if (select to_jsonb(t) from public.staff_transactions() t where id=sale_id) is distinct from original then raise exception 'Original receipt modified';end if;
 select sum(total_cents) into qty from public.staff_transactions() t where id in(sale_id,void_id);if qty<>0 then raise exception 'Void total wrong';end if;
 blocked:=false;begin perform public.void_sale(gen_random_uuid(),sale_id,shift_id,'Second reversal');exception when others then blocked:=true;end;if not blocked then raise exception 'Second void accepted';end if;
 perform public.close_shift(shift_id,now());
 execute 'reset role';
 blocked:=false;begin update public.transactions set total_cents=1 where id=sale_id;exception when others then blocked:=true;end;if not blocked then raise exception 'Immutable receipt trigger failed';end if;
 if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in('public','private') and c.relkind='r' and not c.relrowsecurity) then raise exception 'Table without RLS';end if;
end $$;
select 'PASS: authorization, atomic sale, exact retries, stock, immutable reversal, duplicate void, RLS and rollback' as result;
rollback;
