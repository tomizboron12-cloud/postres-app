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
