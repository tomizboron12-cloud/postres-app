-- ============================================================
-- Migración: precio real vs. precio estimado en Ingredientes.
-- Pegar y ejecutar SOLO este archivo en: Supabase > SQL Editor > New query > Run
-- No afecta ningún dato existente (solo agrega una columna nueva,
-- y la completa con el precio actual para no dejar nada vacío).
-- ============================================================

alter table ingredients add column if not exists real_price numeric;

-- Para los ingredientes que ya existían, arrancamos con el precio real
-- igual al estimado (se puede corregir después desde la app).
update ingredients set real_price = price where real_price is null;
