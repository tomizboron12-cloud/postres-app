-- ============================================================
-- Migración: Calculadora de costos (ingredientes, recetas, packaging, costeo)
-- Pegar y ejecutar SOLO este archivo en: Supabase > SQL Editor > New query > Run
-- No afecta ninguna tabla ni dato existente.
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists ingredients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price numeric not null default 0,
  package_qty numeric not null default 0,
  unit text not null default 'g',
  created_at timestamptz not null default now()
);

create table if not exists recipes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  yield_qty numeric not null default 0,
  yield_unit text not null default 'g',
  created_at timestamptz not null default now()
);

create table if not exists recipe_items (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references recipes(id) on delete cascade,
  ingredient_id uuid references ingredients(id) on delete set null,
  qty numeric not null default 0
);

create table if not exists packaging_catalog (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cost numeric not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists cost_products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists cost_product_ingredients (
  id uuid primary key default gen_random_uuid(),
  cost_product_id uuid not null references cost_products(id) on delete cascade,
  ingredient_id uuid references ingredients(id) on delete set null,
  qty numeric not null default 0
);

create table if not exists cost_product_recipes (
  id uuid primary key default gen_random_uuid(),
  cost_product_id uuid not null references cost_products(id) on delete cascade,
  recipe_id uuid references recipes(id) on delete set null,
  qty numeric not null default 0
);

create table if not exists cost_product_packaging (
  id uuid primary key default gen_random_uuid(),
  cost_product_id uuid not null references cost_products(id) on delete cascade,
  packaging_id uuid not null references packaging_catalog(id) on delete cascade
);

alter table ingredients enable row level security;
alter table recipes enable row level security;
alter table recipe_items enable row level security;
alter table packaging_catalog enable row level security;
alter table cost_products enable row level security;
alter table cost_product_ingredients enable row level security;
alter table cost_product_recipes enable row level security;
alter table cost_product_packaging enable row level security;

drop policy if exists "anon full access" on ingredients;
drop policy if exists "anon full access" on recipes;
drop policy if exists "anon full access" on recipe_items;
drop policy if exists "anon full access" on packaging_catalog;
drop policy if exists "anon full access" on cost_products;
drop policy if exists "anon full access" on cost_product_ingredients;
drop policy if exists "anon full access" on cost_product_recipes;
drop policy if exists "anon full access" on cost_product_packaging;

create policy "anon full access" on ingredients for all using (true) with check (true);
create policy "anon full access" on recipes for all using (true) with check (true);
create policy "anon full access" on recipe_items for all using (true) with check (true);
create policy "anon full access" on packaging_catalog for all using (true) with check (true);
create policy "anon full access" on cost_products for all using (true) with check (true);
create policy "anon full access" on cost_product_ingredients for all using (true) with check (true);
create policy "anon full access" on cost_product_recipes for all using (true) with check (true);
create policy "anon full access" on cost_product_packaging for all using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='ingredients') then
    alter publication supabase_realtime add table ingredients;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='recipes') then
    alter publication supabase_realtime add table recipes;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='recipe_items') then
    alter publication supabase_realtime add table recipe_items;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='packaging_catalog') then
    alter publication supabase_realtime add table packaging_catalog;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='cost_products') then
    alter publication supabase_realtime add table cost_products;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='cost_product_ingredients') then
    alter publication supabase_realtime add table cost_product_ingredients;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='cost_product_recipes') then
    alter publication supabase_realtime add table cost_product_recipes;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='cost_product_packaging') then
    alter publication supabase_realtime add table cost_product_packaging;
  end if;
end $$;
