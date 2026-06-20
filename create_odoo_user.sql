DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'odoo') THEN
      CREATE ROLE odoo WITH LOGIN SUPERUSER PASSWORD 'odoo';
   ELSE
      ALTER ROLE odoo WITH LOGIN SUPERUSER PASSWORD 'odoo';
   END IF;
END $$;
SELECT rolname, rolsuper, rolcanlogin FROM pg_roles WHERE rolname = 'odoo';
