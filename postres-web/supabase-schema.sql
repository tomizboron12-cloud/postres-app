-- ============================================================
-- Postres — esquema de base de datos para Supabase
-- Pegar y ejecutar TODO este archivo en: Supabase > SQL Editor > New query > Run
-- ============================================================

create extension if not exists pgcrypto;

-- Dueñas del emprendimiento (fijo: vos y mamá, pero editable)
create table if not exists owners (
  id text primary key,
  name text not null
);
insert into owners (id, name) values ('ella','Sofi'), ('mama','Mamá')
  on conflict (id) do nothing;

-- Productos / postres
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cost numeric not null default 0,
  price numeric not null default 0,
  owner_id text not null references owners(id),
  track_stock boolean not null default true,
  stock integer not null default 0,
  low_stock_alert integer not null default 3,
  created_at timestamptz not null default now()
);

-- Clientes
create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text default '',
  purchase_count integer not null default 0,
  created_at timestamptz not null default now()
);

-- Ventas (cabecera)
create table if not exists sales (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  client_id uuid references clients(id) on delete set null,
  payment_method text default '',
  discount numeric not null default 0,
  created_at timestamptz not null default now()
);

-- Ítems de cada venta — "fotografía" costo/precio/nombre/dueño al momento de vender
create table if not exists sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references sales(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  product_name text not null,
  owner_id text not null references owners(id),
  qty integer not null,
  cost numeric not null,
  price numeric not null
);

-- Compras / gastos
create table if not exists purchases (
  id uuid primary key default gen_random_uuid(),
  description text not null,
  amount numeric not null,
  date date not null,
  owner_id text not null references owners(id),
  category text not null,
  created_at timestamptz not null default now()
);

-- Configuración de fidelidad (una sola fila)
create table if not exists loyalty_config (
  id integer primary key default 1,
  threshold integer not null default 10,
  reward text not null default '1 postre gratis'
);
insert into loyalty_config (id, threshold, reward) values (1, 10, '1 postre gratis')
  on conflict (id) do nothing;

-- ============================================================
-- Calculadora de costos: ingredientes, recetas, catálogo de packaging
-- y costeo de postres. Todo se recalcula al vuelo desde el precio
-- actual de los ingredientes (no se guarda ningún costo fijo acá).
-- ============================================================
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

create policy "anon full access" on ingredients for all using (true) with check (true);
create policy "anon full access" on recipes for all using (true) with check (true);
create policy "anon full access" on recipe_items for all using (true) with check (true);
create policy "anon full access" on packaging_catalog for all using (true) with check (true);
create policy "anon full access" on cost_products for all using (true) with check (true);
create policy "anon full access" on cost_product_ingredients for all using (true) with check (true);
create policy "anon full access" on cost_product_recipes for all using (true) with check (true);
create policy "anon full access" on cost_product_packaging for all using (true) with check (true);

alter publication supabase_realtime add table ingredients;
alter publication supabase_realtime add table recipes;
alter publication supabase_realtime add table recipe_items;
alter publication supabase_realtime add table packaging_catalog;
alter publication supabase_realtime add table cost_products;
alter publication supabase_realtime add table cost_product_ingredients;
alter publication supabase_realtime add table cost_product_recipes;
alter publication supabase_realtime add table cost_product_packaging;

-- ============================================================
-- Funciones atómicas (evitan pisadas de datos si las dos usan la app
-- al mismo tiempo desde distintos dispositivos)
-- ============================================================
create or replace function adjust_stock(p_product_id uuid, p_delta integer)
returns integer as $$
  update products set stock = greatest(0, stock + p_delta)
  where id = p_product_id
  returning stock;
$$ language sql;

create or replace function adjust_purchase_count(p_client_id uuid, p_delta integer)
returns integer as $$
  update clients set purchase_count = greatest(0, purchase_count + p_delta)
  where id = p_client_id
  returning purchase_count;
$$ language sql;

-- ============================================================
-- Realtime: para que los cambios se vean en vivo en ambos dispositivos
-- ============================================================
alter publication supabase_realtime add table products;
alter publication supabase_realtime add table clients;
alter publication supabase_realtime add table sales;
alter publication supabase_realtime add table sale_items;
alter publication supabase_realtime add table purchases;
alter publication supabase_realtime add table loyalty_config;
alter publication supabase_realtime add table owners;

-- ============================================================
-- Seguridad: la app usa selector simple de usuario (sin contraseña),
-- así que habilitamos RLS con políticas abiertas para la clave anon.
-- (Solo quienes tengan el link de la app pueden leer/escribir.)
-- ============================================================
alter table owners enable row level security;
alter table products enable row level security;
alter table clients enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;
alter table purchases enable row level security;
alter table loyalty_config enable row level security;

create policy "anon full access" on owners for all using (true) with check (true);
create policy "anon full access" on products for all using (true) with check (true);
create policy "anon full access" on clients for all using (true) with check (true);
create policy "anon full access" on sales for all using (true) with check (true);
create policy "anon full access" on sale_items for all using (true) with check (true);
create policy "anon full access" on purchases for all using (true) with check (true);
create policy "anon full access" on loyalty_config for all using (true) with check (true);

-- ============================================================
-- Stock de ingredientes, vínculo producto-costeo, compras de
-- ingredientes automáticas y lista de compras.
-- ============================================================
alter table ingredients add column if not exists current_stock numeric not null default 0;
alter table ingredients add column if not exists low_stock_alert numeric not null default 0;

alter table products add column if not exists cost_product_id uuid references cost_products(id) on delete set null;

alter table purchases add column if not exists ingredient_id uuid references ingredients(id) on delete set null;
alter table purchases add column if not exists ingredient_qty numeric;
alter table purchases add column if not exists packaging_id uuid references packaging_catalog(id) on delete set null;
alter table purchases add column if not exists packaging_qty numeric;

create table if not exists shopping_list_manual (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  checked boolean not null default false,
  created_at timestamptz not null default now()
);
alter table shopping_list_manual enable row level security;
create policy "anon full access" on shopping_list_manual for all using (true) with check (true);
alter publication supabase_realtime add table shopping_list_manual;

create or replace function adjust_ingredient_stock(p_ingredient_id uuid, p_delta numeric)
returns numeric as $$
  update ingredients set current_stock = current_stock + p_delta
  where id = p_ingredient_id
  returning current_stock;
$$ language sql;

-- ============================================================
-- Stock de recetas preparadas, stock de packaging y producción
-- incompleta (work in progress).
-- ============================================================
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
create policy "anon full access" on work_in_progress for all using (true) with check (true);
alter publication supabase_realtime add table work_in_progress;

create or replace function adjust_recipe_stock(p_recipe_id uuid, p_delta numeric)
returns numeric as $$
  update recipes set current_stock = current_stock + p_delta
  where id = p_recipe_id
  returning current_stock;
$$ language sql;

create or replace function adjust_packaging_stock(p_packaging_id uuid, p_delta numeric)
returns numeric as $$
  update packaging_catalog set current_stock = current_stock + p_delta
  where id = p_packaging_id
  returning current_stock;
$$ language sql;
