-- ============================================================
-- Migración: categorías de productos (Postres, Tortas, Shots, etc.)
-- Pegar y ejecutar SOLO este archivo en: Supabase > SQL Editor > New query > Run
-- No borra ni modifica ningún producto existente: solo agrega una tabla
-- nueva de categorías y una columna nueva en productos. Todos los
-- productos que ya tenías quedan agrupados en la categoría "Postres"
-- para que nada quede "sin categoría" de golpe.
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists product_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table product_categories enable row level security;
drop policy if exists "anon full access" on product_categories;
create policy "anon full access" on product_categories for all using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='product_categories') then
    alter publication supabase_realtime add table product_categories;
  end if;
end $$;

-- Categoría por defecto para no dejar los productos existentes sin categoría.
insert into product_categories (name, sort_order)
select 'Postres', 0
where not exists (select 1 from product_categories where name='Postres');

alter table products add column if not exists category_id uuid references product_categories(id) on delete set null;

update products set category_id = (select id from product_categories where name='Postres' limit 1)
where category_id is null;
