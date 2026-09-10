-- ============================================================
-- Migración: Encargos (pedidos a futuro con seña / resto / recordatorio).
-- Pegar y ejecutar SOLO este archivo en: Supabase > SQL Editor > New query > Run
-- No toca ninguna tabla existente: solo crea dos tablas nuevas.
-- Requiere haber corrido antes supabase-migration-product-categories.sql
-- (los items del encargo referencian product_categories).
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists custom_orders (
  id uuid primary key default gen_random_uuid(),
  client_name text not null,
  client_id uuid references clients(id) on delete set null,
  order_date date not null default current_date,
  due_date date not null,
  due_time text,
  total_amount numeric not null default 0,
  deposit_amount numeric not null default 0,
  deposit_method text default '',
  remaining_method text default '',
  remaining_paid boolean not null default false,
  status text not null default 'pendiente',
  notes text default '',
  created_at timestamptz not null default now()
);

create table if not exists custom_order_items (
  id uuid primary key default gen_random_uuid(),
  custom_order_id uuid not null references custom_orders(id) on delete cascade,
  category_id uuid references product_categories(id) on delete set null,
  category_name text not null default '',
  flavor text default '',
  qty numeric not null default 1
);

alter table custom_orders enable row level security;
alter table custom_order_items enable row level security;
drop policy if exists "anon full access" on custom_orders;
drop policy if exists "anon full access" on custom_order_items;
create policy "anon full access" on custom_orders for all using (true) with check (true);
create policy "anon full access" on custom_order_items for all using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='custom_orders') then
    alter publication supabase_realtime add table custom_orders;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='custom_order_items') then
    alter publication supabase_realtime add table custom_order_items;
  end if;
end $$;
