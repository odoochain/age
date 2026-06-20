ALTER DATABASE baraka OWNER TO odoo;
ALTER SCHEMA public OWNER TO odoo;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
    EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' OWNER TO odoo';
  END LOOP;
END $$;

SELECT 'Tables owned by odoo:' AS info;
SELECT count(*) AS table_count FROM pg_tables WHERE schemaname='public' AND tableowner='odoo';
