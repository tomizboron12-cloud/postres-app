-- ============================================================
-- Migración: compras de packaging con desplegable + auto-stock
-- (igual que ya funciona con Ingredientes).
-- Pegar y ejecutar SOLO este archivo en: Supabase > SQL Editor > New query > Run
-- No afecta ninguna tabla ni dato existente (solo agrega columnas nuevas).
-- ============================================================

alter table purchases add column if not exists packaging_id uuid references packaging_catalog(id) on delete set null;
alter table purchases add column if not exists packaging_qty numeric;
