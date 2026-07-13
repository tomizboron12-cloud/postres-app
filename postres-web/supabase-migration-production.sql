-- ============================================================
-- Migración: stock de recetas preparadas, stock de packaging,
-- producción incompleta (work in progress) y fix del descuento
-- de stock (recetas descuentan de su propio stock, no de los
-- ingredientes crudos de nuevo).
-- Pegar y ejecutar SOLO este archivo en: Supabase > SQL Editor > New query > Run
-- No afecta ninguna tabla ni dato existente (solo agrega columnas/tablas nuevas).
-- ============================================================

create extension if not exists pgcrypto;

alter table recipes add column if not exists current_stock numeric not null default 0;
alter table recipes add column if not exists low_stock_alert numeric not null default 0;

alter table packaging_catalog add column if not exists current_stock numeric not null default 0;
alter table packaging_catalog add column if not exists low_stock_alert numeric not null default 0;

create table if not exists work_in_progress (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references products(id) on delete set null,
  qty numeric not null,
  date date not null default current_date,
  used_ingredient_ids uuid[] not null default '{}',
  used_recipe_ids uuid[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table work_in_progress enable row level security;
drop policy if exists "anon full access" on work_in_progress;
create policy "anon full access" on work_in_progress for all using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='work_in_progress') then
    alter publication supabase_realtime add table work_in_progress;
  end if;
end $$;

-- Ajusta el stock de una receta preparada de forma atómica (sin piso en 0).
create or replace function adjust_recipe_stock(p_recipe_id uuid, p_delta numeric)
returns numeric as $$
  update recipes set current_stock = current_stock + p_delta
  where id = p_recipe_id
  returning current_stock;
$$ language sql;

-- Ajusta el stock de un ítem de packaging de forma atómica (sin piso en 0).
create or replace function adjust_packaging_stock(p_packaging_id uuid, p_delta numeric)
returns numeric as $$
  update packaging_catalog set current_stock = current_stock + p_delta
  where id = p_packaging_id
  returning current_stock;
$$ language sql;
