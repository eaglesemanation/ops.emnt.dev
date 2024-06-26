\c immich
GRANT USAGE, CREATE ON SCHEMA public TO immich;

BEGIN;
ALTER DATABASE immich OWNER TO immich;
CREATE EXTENSION vector;
CREATE EXTENSION earthdistance CASCADE;
ALTER DATABASE immich SET search_path TO "$user", public, vectors;
COMMIT;
