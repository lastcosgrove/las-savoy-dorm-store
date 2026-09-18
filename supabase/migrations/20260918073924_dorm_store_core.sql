-- Production database foundation for the selected EU project.
-- The current UI is deliberately a separate practice workspace.
create extension if not exists pgcrypto with schema extensions;
create table public.operators (
 id uuid primary key default gen_random_uuid(), auth_user_id uuid unique references auth.users(id),
 name text not null, role text not null check(role in ('staff','prefect')),
 active boolean not null default true, created_at timestamptz not null default now()
);
-- PIN verifiers are never readable through the public API.
create schema if not exists private;
revoke all on schema private from public,anon,authenticated;
create table private.operator_pins(operator_id uuid primary key references public.operators(id),pin_hash text not null,failed_attempts int not null default 0,locked_until timestamptz);
create table public.students (
 id uuid primary key default gen_random_uuid(),student_number text unique not null,
 first_name text not null,last_name text not null,dorm text,grade_level text,card_uid_hash text unique,
 spending_limit_cents integer check(spending_limit_cents>=0),limit_period text not null default 'week' check(limit_period in('week','month','term')),
 active boolean not null default true,created_at timestamptz not null default now()
);
create table public.products (
 id uuid primary key default gen_random_uuid(),name text not null,category text not null,
 price_cents integer not null check(price_cents>=0),barcode text,image_url text,
 sort_order integer not null default 0,active boolean not null default true,
 low_stock_threshold integer not null default 5 check(low_stock_threshold>=0),created_at timestamptz not null default now()
);
create table public.price_history (
 id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id),
 price_cents integer not null check(price_cents>=0),product_name text not null,
 effective_from timestamptz not null default now(),changed_by uuid not null references public.operators(id)
);
create index price_history_lookup on public.price_history(product_id,effective_from desc);
create table public.shifts (
 id uuid primary key,operator_id uuid not null references public.operators(id),opened_at timestamptz not null,
 closed_at timestamptz,device_id uuid not null,notes text,check(closed_at is null or closed_at>=opened_at)
);
create table public.transactions (
 id uuid primary key,student_id uuid not null references public.students(id),shift_id uuid not null references public.shifts(id),
 operator_id uuid not null references public.operators(id),total_cents integer not null,occurred_at timestamptz not null,
 synced_at timestamptz not null default now(),is_void boolean not null default false,
 original_transaction_id uuid unique references public.transactions(id),note text,device_id uuid not null,
 source_payload jsonb not null,
 check((not is_void and original_transaction_id is null and total_cents>=0) or (is_void and original_transaction_id is not null and total_cents<=0 and length(trim(note))>0))
);
create table public.transaction_items (
 id uuid primary key default gen_random_uuid(),transaction_id uuid not null references public.transactions(id),
 product_id uuid not null references public.products(id),product_name text not null,
 quantity integer not null check(quantity>0),unit_price_cents integer not null check(unit_price_cents>=0),
 line_total_cents integer not null check(line_total_cents=quantity*unit_price_cents)
);
create table public.count_sessions (
 id uuid primary key,operator_id uuid not null references public.operators(id),started_at timestamptz not null,completed_at timestamptz,notes text
);
create table public.count_lines (
 id uuid primary key default gen_random_uuid(),count_session_id uuid not null references public.count_sessions(id),
 product_id uuid not null references public.products(id),expected_qty integer not null,counted_qty integer not null check(counted_qty>=0),
 variance integer generated always as(counted_qty-expected_qty) stored,unique(count_session_id,product_id)
);
create table public.stock_movements (
 id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id),quantity_delta integer not null,
 movement_type text not null check(movement_type in('delivery','sale','void','adjustment','count_correction','damage','comp')),
 transaction_id uuid references public.transactions(id),count_session_id uuid references public.count_sessions(id),
 operator_id uuid not null references public.operators(id),note text,occurred_at timestamptz not null default now()
);
create index movements_product on public.stock_movements(product_id);
create index transactions_student_time on public.transactions(student_id,occurred_at);
create table private.audit_log(id bigint generated always as identity primary key,operator_id uuid references public.operators(id),action text not null,record_id uuid,occurred_at timestamptz not null default now());
create function private.actor_id() returns uuid language sql stable security definer set search_path='' as $$
 select id from public.operators where auth_user_id=(select auth.uid()) and active
$$;
create function private.is_staff() returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select role='staff' from public.operators where id=private.actor_id()),false)
$$;
-- Policies may call these helpers, but the private schema and PIN table remain unexposed.
grant usage on schema private to authenticated;
grant execute on function private.actor_id(),private.is_staff() to authenticated;
create function private.immutable_ledger() returns trigger language plpgsql set search_path='' as $$
 begin raise exception 'Ledger records are immutable; insert a compensating entry';end
$$;
create trigger immutable_transactions before update or delete on public.transactions for each row execute function private.immutable_ledger();
create trigger immutable_items before update or delete on public.transaction_items for each row execute function private.immutable_ledger();
create trigger immutable_stock before update or delete on public.stock_movements for each row execute function private.immutable_ledger();
create trigger immutable_prices before update or delete on public.price_history for each row execute function private.immutable_ledger();
-- No client role can mutate base tables. Only narrowly scoped RPCs may write.
do $$ declare t text;begin
 foreach t in array array['operators','students','products','price_history','shifts','transactions','transaction_items','stock_movements','count_sessions','count_lines'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon,authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 end loop;end $$;
create policy roster_read on public.students for select to authenticated using((select private.actor_id()) is not null);
create policy products_read on public.products for select to authenticated using((select private.actor_id()) is not null);
create policy operators_read on public.operators for select to authenticated using((select private.actor_id()) is not null);
create policy prices_read on public.price_history for select to authenticated using((select private.actor_id()) is not null);
create policy stock_read on public.stock_movements for select to authenticated using((select private.actor_id()) is not null);
create policy shifts_read on public.shifts for select to authenticated using(operator_id=(select private.actor_id()) or (select private.is_staff()));
-- Student-level financial data is returned only by a logged staff-report RPC.
create view public.current_stock with(security_invoker=true) as
 select p.id,p.name,p.category,p.price_cents,p.low_stock_threshold,coalesce(sum(m.quantity_delta),0)::bigint as qty_on_hand
 from public.products p left join public.stock_movements m on m.product_id=p.id where p.active group by p.id;
grant select on public.current_stock to authenticated;
create function private.open_shift(p_id uuid,p_opened_at timestamptz,p_device_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
 declare actor uuid:=private.actor_id();prior public.shifts;begin
 if actor is null then raise exception 'Operator access required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_device_id::text,0));
 select * into prior from public.shifts where id=p_id;
 if found then if prior.operator_id is distinct from actor or prior.device_id is distinct from p_device_id or prior.opened_at is distinct from p_opened_at then raise exception 'Shift conflict';end if;return p_id;end if;
 if p_opened_at is null or p_opened_at>now()+interval '5 minutes' then raise exception 'Invalid start time';end if;
 if exists(select 1 from public.shifts where device_id=p_device_id and closed_at is null) then raise exception 'Previous shift must be closed';end if;
 insert into public.shifts(id,operator_id,opened_at,device_id) values(p_id,actor,p_opened_at,p_device_id);return p_id;
 end $$;
create function private.close_shift(p_id uuid,p_closed_at timestamptz) returns void language plpgsql security definer set search_path='' as $$
 begin
 if private.actor_id() is null then raise exception 'Operator access required';end if;
 if p_closed_at is null or p_closed_at>now()+interval '5 minutes' then raise exception 'Invalid end time';end if;
 update public.shifts set closed_at=p_closed_at where id=p_id and (operator_id=private.actor_id() or private.is_staff()) and closed_at is null and p_closed_at>=opened_at;
 if not found and not exists(select 1 from public.shifts where id=p_id and closed_at=p_closed_at and (operator_id=private.actor_id() or private.is_staff())) then raise exception 'Shift unavailable or already closed';end if;
 end $$;
create function private.ingest_sale(p jsonb) returns uuid language plpgsql security definer set search_path='' as $$
 declare actor uuid:=private.actor_id();sid uuid:=(p->>'id')::uuid;row_item jsonb;product public.products;prior public.transactions;s public.shifts;
 expected_price integer;expected_name text;qty integer;price integer;total bigint:=0;occurred timestamptz:=(p->>'occurred_at')::timestamptz;
 begin
 if actor is null or (p->>'operator_id')::uuid is distinct from actor then raise exception 'Operator mismatch';end if;
 perform pg_advisory_xact_lock(hashtextextended(sid::text,0));
 select * into prior from public.transactions where id=sid;
 if found then if prior.source_payload is distinct from p then raise exception 'Idempotency conflict';end if;return sid;end if;
 select * into s from public.shifts where id=(p->>'shift_id')::uuid;
 if s.id is null or s.operator_id<>actor or s.device_id is distinct from (p->>'device_id')::uuid then raise exception 'Invalid shift';end if;
 if occurred is null or occurred<s.opened_at or (s.closed_at is not null and occurred>s.closed_at) or occurred>now()+interval '5 minutes' then raise exception 'Invalid sale time';end if;
 if not exists(select 1 from public.students where id=(p->>'student_id')::uuid and active) then raise exception 'Student unavailable';end if;
 if exists(select 1 from public.students where id=(p->>'student_id')::uuid and spending_limit_cents is not null) then raise exception 'Spending-limit policy is not configured; staff review required';end if;
 if jsonb_typeof(p->'items') is distinct from 'array' or coalesce(jsonb_array_length(p->'items'),0) not between 1 and 100 then raise exception 'Invalid items';end if;
 for row_item in select value from jsonb_array_elements(p->'items') loop
 qty:=(row_item->>'quantity')::integer;price:=(row_item->>'unit_price_cents')::integer;
 if qty is null or price is null or qty not between 1 and 1000 or price<0 then raise exception 'Invalid quantity or price';end if;
 select * into product from public.products where id=(row_item->>'product_id')::uuid;
 if product.id is null then raise exception 'Unknown product';end if;
 select price_cents,product_name into expected_price,expected_name from public.price_history where product_id=product.id and effective_from<=occurred order by effective_from desc limit 1;
 if expected_price is null or price is distinct from expected_price or row_item->>'product_name' is distinct from expected_name then raise exception 'Catalog mismatch; staff review required';end if;
 if (row_item->>'line_total_cents')::bigint is distinct from qty::bigint*price then raise exception 'Line total mismatch';end if;
 total:=total+qty::bigint*price;
 end loop;
 if total is distinct from (p->>'total_cents')::bigint or total>2147483647 then raise exception 'Total mismatch';end if;
 insert into public.transactions(id,student_id,shift_id,operator_id,total_cents,occurred_at,device_id,source_payload)
 values(sid,(p->>'student_id')::uuid,s.id,actor,total,occurred,s.device_id,p);
 for row_item in select value from jsonb_array_elements(p->'items') loop
 insert into public.transaction_items(transaction_id,product_id,product_name,quantity,unit_price_cents,line_total_cents)
 values(sid,(row_item->>'product_id')::uuid,row_item->>'product_name',(row_item->>'quantity')::int,(row_item->>'unit_price_cents')::int,(row_item->>'line_total_cents')::int);
 insert into public.stock_movements(product_id,quantity_delta,movement_type,transaction_id,operator_id,occurred_at)
 values((row_item->>'product_id')::uuid,-(row_item->>'quantity')::int,'sale',sid,actor,occurred);
 end loop;return sid;
 end $$;
create function private.void_sale(p_id uuid,p_original uuid,p_shift uuid,p_reason text) returns uuid language plpgsql security definer set search_path='' as $$
 declare original public.transactions;s public.shifts;actor uuid:=private.actor_id();begin
 if not private.is_staff() or p_reason is null or length(trim(p_reason))=0 then raise exception 'Staff and reason required';end if;
 select * into original from public.transactions where id=p_original for update;
 if original.id is null or original.is_void then raise exception 'Original sale required';end if;
 if exists(select 1 from public.transactions where id=p_id and original_transaction_id=p_original and operator_id=actor and note=p_reason) then return p_id;end if;
 if exists(select 1 from public.transactions where original_transaction_id=p_original) then raise exception 'Already voided';end if;
 select * into s from public.shifts where id=p_shift;
 if s.id is null or s.closed_at is not null or s.operator_id is distinct from actor then raise exception 'Open shift required';end if;
 insert into public.transactions(id,student_id,shift_id,operator_id,total_cents,occurred_at,is_void,original_transaction_id,note,device_id,source_payload)
 values(p_id,original.student_id,s.id,actor,-original.total_cents,now(),true,p_original,p_reason,s.device_id,jsonb_build_object('original_transaction_id',p_original,'note',p_reason));
 insert into public.transaction_items(transaction_id,product_id,product_name,quantity,unit_price_cents,line_total_cents)
 select p_id,product_id,product_name,quantity,unit_price_cents,line_total_cents from public.transaction_items where transaction_id=p_original;
 insert into public.stock_movements(product_id,quantity_delta,movement_type,transaction_id,operator_id,note)
 select product_id,quantity,'void',p_id,actor,p_reason from public.transaction_items where transaction_id=p_original;return p_id;
 end $$;
create function private.staff_transactions() returns setof public.transactions language plpgsql security definer set search_path='' as $$
 begin if not private.is_staff() then raise exception 'Staff access required';end if;
 insert into private.audit_log(operator_id,action) values(private.actor_id(),'view_transactions');
 return query select * from public.transactions order by occurred_at desc;end $$;
-- Public RPC wrappers run as the caller. Privileged implementations remain private.
create function public.open_shift(p_id uuid,p_opened_at timestamptz,p_device_id uuid) returns uuid language sql security invoker set search_path='' as $$ select private.open_shift(p_id,p_opened_at,p_device_id) $$;
create function public.close_shift(p_id uuid,p_closed_at timestamptz) returns void language sql security invoker set search_path='' as $$ select private.close_shift(p_id,p_closed_at) $$;
create function public.ingest_sale(p jsonb) returns uuid language sql security invoker set search_path='' as $$ select private.ingest_sale(p) $$;
create function public.void_sale(p_id uuid,p_original uuid,p_shift uuid,p_reason text) returns uuid language sql security invoker set search_path='' as $$ select private.void_sale(p_id,p_original,p_shift,p_reason) $$;
create function public.staff_transactions() returns setof public.transactions language sql security invoker set search_path='' as $$ select * from private.staff_transactions() $$;
revoke all on all functions in schema private from public,anon,authenticated;
grant execute on function private.actor_id(),private.is_staff(),private.open_shift(uuid,timestamptz,uuid),private.close_shift(uuid,timestamptz),private.ingest_sale(jsonb),private.void_sale(uuid,uuid,uuid,text),private.staff_transactions() to authenticated;
alter table private.operator_pins enable row level security;
alter table private.audit_log enable row level security;
revoke all on all tables in schema private from public,anon,authenticated;
-- Explicit execution allowlist: functions default to PUBLIC execute in Postgres.
revoke all on function public.open_shift(uuid,timestamptz,uuid),public.close_shift(uuid,timestamptz),public.ingest_sale(jsonb),public.void_sale(uuid,uuid,uuid,text),public.staff_transactions() from public,anon;
grant execute on function public.open_shift(uuid,timestamptz,uuid),public.close_shift(uuid,timestamptz),public.ingest_sale(jsonb),public.void_sale(uuid,uuid,uuid,text),public.staff_transactions() to authenticated;
revoke all on function private.actor_id(),private.is_staff(),private.immutable_ledger() from public,anon;
-- Catalog/admin writes, PIN lease issuance, device enrollment and retention are
-- intentionally launch gates; there is no permissive policy as a temporary bypass.
