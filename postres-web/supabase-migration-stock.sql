-- ============================================================
-- Migración: stock de ingredientes, vínculo producto-costeo,
-- compras de ingredientes automáticas y lista de compras.
-- Pegar y ejecutar SOLO este archivo en: Supabase > SQL Editor > New query > Run
-- No afecta ninguna tabla ni dato existente (solo agrega columnas/tablas nuevas).
-- ============================================================

create extension if not exists pgcrypto;

alter table ingredients add column if not exists current_stock numeric not null default 0;
alter table ingredients add column if not exists low_stock_alert numeric not null default 0;

alter table products add column if not exists cost_product_id uuid references cost_products(id) on delete set null;

alter table purchases add column if not exists ingredient_id uuid references ingredients(id) on delete set null;
alter table purchases add column if not exists ingredient_qty numeric;

create table if not exists shopping_list_manual (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  checked boolean not null default false,
  created_at timestamptz not null default now()
);

alter table shopping_list_manual enable row level security;
drop policy if exists "anon full access" on shopping_list_manual;
create policy "anon full access" on shopping_list_manual for all using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='shopping_list_manual') then
    alter publication supabase_realtime add table shopping_list_manual;
  end if;
end $$;

-- Ajusta el stock de un ingrediente de forma atómica (sin piso en 0:
-- si se descuenta de más queda en negativo, igual que la referencia,
-- para que se note que faltó comprar a tiempo).
create or replace function adjust_ingredient_stock(p_ingredient_id uuid, p_delta numeric)
returns numeric as $$
  update ingredients set current_stock = current_stock + p_delta
  where id = p_ingredient_id
  returning current_stock;
$$ language sql;
