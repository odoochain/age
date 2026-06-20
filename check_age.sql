SELECT 'installed_extensions' AS check, extname, extversion FROM pg_extension WHERE extname = 'age'
UNION ALL
SELECT 'available_extensions', name, default_version FROM pg_available_extensions WHERE name = 'age';
