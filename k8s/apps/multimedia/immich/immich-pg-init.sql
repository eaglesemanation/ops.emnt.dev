\c immich
BEGIN;
GRANT USAGE, CREATE ON SCHEMA public TO immich;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;
COMMIT;
