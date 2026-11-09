-- migration_3nf.sql : découpage de extrait_plat en 4 tables BCNF (TP Jour 1, Lab 5, étapes 5.1 et 5.2)
-- Groupe : Praveen, Ugo, Hugo, Corentin
-- Lancement (dans le terminal) :
--   psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f migration_3nf.sql
--
-- Règle : une table par déterminant (partie gauche d'une dépendance du lab 4).
--   site_id                  -> site_nom, pays             => norm.site
--   telephone                -> apicultrice, cooperative   => norm.apicultrice
--   ruche_code               -> site_id, telephone         => norm.ruche
--   ruche_code, horodatage   -> poids_kg, temp_int_c       => norm.mesure
-- Les noms de colonnes sont ceux de extrait_plat : la vue norm.reconstruit
-- (étape 5.3, dans anomalies.sql) n'a qu'à refaire les jointures.
-- Le fichier peut être relancé : DROP SCHEMA ... CASCADE efface tout (vue comprise).

BEGIN;
DROP SCHEMA IF EXISTS norm CASCADE;
CREATE SCHEMA norm;

CREATE TABLE norm.site (                      -- déterminant : site_id
  site_id   text PRIMARY KEY,
  site_nom  text NOT NULL,
  pays      text NOT NULL
);

CREATE TABLE norm.apicultrice (               -- déterminant : telephone
  telephone    text PRIMARY KEY,
  apicultrice  text NOT NULL,
  cooperative  text NOT NULL
);

CREATE TABLE norm.ruche (                     -- déterminant : ruche_code
  ruche_code  text PRIMARY KEY,
  site_id     text NOT NULL REFERENCES norm.site (site_id),
  telephone   text NOT NULL REFERENCES norm.apicultrice (telephone)
);

CREATE TABLE norm.mesure (                    -- clé : (ruche_code, horodatage)
  ruche_code  text NOT NULL REFERENCES norm.ruche (ruche_code),
  horodatage  timestamptz NOT NULL,
  poids_kg    numeric(5,2),
  temp_int_c  numeric(4,1),
  PRIMARY KEY (ruche_code, horodatage)
);

-- Ordre des INSERT : d'abord les tables référencées, puis celles qui pointent vers elles
INSERT INTO norm.site        SELECT DISTINCT site_id, site_nom, pays FROM extrait_plat;
INSERT INTO norm.apicultrice SELECT DISTINCT telephone, apicultrice, cooperative FROM extrait_plat;
INSERT INTO norm.ruche       SELECT DISTINCT ruche_code, site_id, telephone FROM extrait_plat;
INSERT INTO norm.mesure      SELECT DISTINCT ruche_code, horodatage, poids_kg, temp_int_c FROM extrait_plat;

COMMIT;

-- ===========================================================================
-- RÉSULTATS OBTENUS (vrais résultats, terminal)
-- ===========================================================================
--
-- 1) Premier lancement, sur les données corrompues par l'étape 5.1
--    (SN-KOLD a deux pays, CI-YAMO-001 a deux téléphones) : REFUS attendu
--
-- $ psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f migration_3nf.sql
-- BEGIN
-- psql:migration_3nf.sql:16: NOTICE:  schema "norm" does not exist, skipping
-- DROP SCHEMA
-- CREATE SCHEMA
-- CREATE TABLE
-- CREATE TABLE
-- CREATE TABLE
-- CREATE TABLE
-- psql:migration_3nf.sql:46: ERROR:  duplicate key value violates unique constraint "site_pkey"
-- DETAIL:  Key (site_id)=(SN-KOLD) already exists.
--
--    Toute la transaction est annulée : le schéma norm n'existe pas.
--    Le refus porte sur le premier conflit rencontré (norm.site) ; le second
--    (ruche_code CI-YAMO-001 avec deux téléphones) aurait été refusé par
--    ruche_pkey. Les deux sont retrouvés et corrigés dans anomalies.sql (étape 5.2).
--
-- 2) Second lancement, après le nettoyage (anomalies.sql, étape 5.2) : PASSE
--
-- $ psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f migration_3nf.sql
-- BEGIN
-- psql:migration_3nf.sql:16: NOTICE:  schema "norm" does not exist, skipping
-- DROP SCHEMA
-- CREATE SCHEMA
-- CREATE TABLE
-- CREATE TABLE
-- CREATE TABLE
-- CREATE TABLE
-- INSERT 0 4
-- INSERT 0 8
-- INSERT 0 11
-- INSERT 0 528
-- COMMIT
--    (si norm existe déjà, par exemple au 2e passage, le NOTICE est remplacé
--     par « NOTICE: drop cascades to ... » : normal, le schéma est recréé)
--
--    4 sites, 8 apicultrices, 11 ruches, 528 mesures : conforme à l'attendu.
--    La PRIMARY KEY (ruche_code, horodatage) ajoutée à extrait_plat en 5.1 ne
--    gêne pas : elle garantit au contraire que les 528 lignes de norm.mesure
--    sont toutes distinctes.
