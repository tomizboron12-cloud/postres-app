-- ============================================================
-- Migración: tipo de consumo de packaging (producción/venta/ninguno)
-- y bolsas usadas en la venta.
-- Pegar y ejecutar SOLO este archivo en: Supabase > SQL Editor > New query > Run
-- No afecta ninguna tabla ni dato existente (solo agrega columnas/tablas nuevas).
-- ============================================================

create extension if not exists pgcrypto;

alter table packaging_catalog add column if not exists consumption_type text not null default 'produccion';

create table if not exists sale_bags (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references sales(id) on delete cascade,
  packaging_id uuid references packaging_catalog(id) on delete set null,
  qty numeric not null
);

alter table sale_bags enable row level security;
drop policy if exists "anon full access" on sale_bags;
create policy "anon full access" on sale_bags for all using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='sale_bags') then
    alter publication supabase_realtime add table sale_bags;
  end if;
end $$;
