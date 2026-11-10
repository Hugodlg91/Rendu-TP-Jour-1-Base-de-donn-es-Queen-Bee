-- schema.sql : base Queen Bee (TP Jour 1, Lab 2)
-- Groupe : Praveen, Ugo, Hugo, Corentin
-- Lancement : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f schema.sql
-- 10 tables, 14 clés étrangères nommées table_colonne_fk, chacune couverte par un index
-- (corrections suite au retour de la prof : voir RENDU.md, section 7)

-- On supprime tout pour pouvoir relancer le fichier autant de fois qu'on veut
DROP TABLE IF EXISTS alerte, recolte, inspection, mesure, utilisateur,
  adhesion, ruche, apicultrice, cooperative, site CASCADE;

-- pgcrypto fournit crypt() et gen_salt() : haché bcrypt par défaut des comptes (table 6)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. SITE : ne pointe vers aucune table, il est créé en premier
--    Clé = code lisible (SN-CASA) : court, stable, pas secret
-- ---------------------------------------------------------------------------
CREATE TABLE site (
  id    text PRIMARY KEY,
  nom   text NOT NULL,
  pays  text NOT NULL
        CHECK (pays IN ('Sénégal', 'Côte d''Ivoire', 'Cameroun'))  -- 3 pays pilotes
);

-- ---------------------------------------------------------------------------
-- 2. COOPÉRATIVE : implantée sur un site (1,1 côté coopérative)
--    Clé = UUID : rien de devinable dans ce qu'une application exposera
-- ---------------------------------------------------------------------------
CREATE TABLE cooperative (
  id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom      text NOT NULL,
  site_id  text NOT NULL CONSTRAINT cooperative_site_fk REFERENCES site(id)
);

-- ---------------------------------------------------------------------------
-- 3. APICULTRICE : rattachée à un site
--    Le nom n'est PAS unique (deux « Aminata Diop ») ; le téléphone l'est
--    (il sert à retrouver l'apicultrice dans donnees.sql)
-- ---------------------------------------------------------------------------
CREATE TABLE apicultrice (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom        text NOT NULL,
  telephone  text NOT NULL UNIQUE,                     -- donnée personnelle (sensible)
  site_id    text NOT NULL CONSTRAINT apicultrice_site_fk REFERENCES site(id),
  -- (id, site_id) est unique puisque id l'est : c'est la cible de la clé
  -- étrangère composée de ruche (une ruche reste sur le site de son apicultrice)
  CONSTRAINT apicultrice_id_site_uq UNIQUE (id, site_id)
);

-- ---------------------------------------------------------------------------
-- 4. RUCHE : appartient à une apicultrice, installée sur le site de celle-ci
--    Le code (SN-CASA-014) ne doit jamais se répéter -> UNIQUE
--    site_id est une redondance CONTRÔLÉE : la clé étrangère composée
--    (apicultrice_id, site_id) interdit qu'il diffère du site de l'apicultrice.
--    Une transhumance sera une entité à part (annotations.md, question 4).
-- ---------------------------------------------------------------------------
CREATE TABLE ruche (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code               text NOT NULL UNIQUE,
  latitude           numeric(8,5) NOT NULL CHECK (latitude  BETWEEN -90  AND 90),   -- sensible
  longitude          numeric(8,5) NOT NULL CHECK (longitude BETWEEN -180 AND 180),  -- sensible
  date_installation  date NOT NULL,
  site_id            text NOT NULL CONSTRAINT ruche_site_fk        REFERENCES site(id),
  apicultrice_id     uuid NOT NULL,
  CONSTRAINT ruche_apicultrice_fk FOREIGN KEY (apicultrice_id, site_id)
    REFERENCES apicultrice (id, site_id)
);

-- ---------------------------------------------------------------------------
-- 5. ADHÉSION : lien n,n apicultrice <-> coopérative, porte la date d'adhésion
--    Clé primaire sur deux colonnes : une apicultrice n'adhère qu'une fois
--    à une même coopérative
-- ---------------------------------------------------------------------------
CREATE TABLE adhesion (
  apicultrice_id  uuid NOT NULL CONSTRAINT adhesion_apicultrice_fk REFERENCES apicultrice(id),
  cooperative_id  uuid NOT NULL CONSTRAINT adhesion_cooperative_fk REFERENCES cooperative(id),
  date_adhesion   date NOT NULL DEFAULT current_date,
  PRIMARY KEY (apicultrice_id, cooperative_id)
);

-- ---------------------------------------------------------------------------
-- 6. UTILISATEUR : compte de connexion, 4 rôles
--    Lien 0,1 - 0,1 avec l'apicultrice -> clé étrangère UNIQUE :
--    une apicultrice n'a jamais deux comptes
--    (le login unique sera posé au lab 4)
-- ---------------------------------------------------------------------------
CREATE TABLE utilisateur (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  login              text NOT NULL,                                    -- sensible
  -- haché bcrypt, jamais en clair. Par défaut : le haché d'un secret aléatoire
  -- que personne ne connaît, le compte s'active par une réinitialisation
  mot_de_passe_hash  text NOT NULL
                     DEFAULT crypt(gen_random_uuid()::text, gen_salt('bf'))
                     CONSTRAINT utilisateur_hache_bcrypt
                     CHECK (mot_de_passe_hash ~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$'),
  role               text NOT NULL
                     CHECK (role IN ('apicultrice', 'coordinateur', 'gestionnaire', 'admin')),
  site_id            text CONSTRAINT utilisateur_site_fk REFERENCES site(id),
  apicultrice_id     uuid UNIQUE CONSTRAINT utilisateur_apicultrice_fk REFERENCES apicultrice(id),
  -- un compte « apicultrice » est relié à une apicultrice, et seulement lui
  CHECK ((role = 'apicultrice') = (apicultrice_id IS NOT NULL)),
  -- l'apicultrice et le coordinateur sont rattachés à un site (moindre privilège)
  CHECK (role NOT IN ('apicultrice', 'coordinateur') OR site_id IS NOT NULL)
);

-- ---------------------------------------------------------------------------
-- 7. MESURE : envoyée par les capteurs d'une ruche (toutes les 30 min)
--    Clé technique bigint (volume élevé, jamais exposée)
--    UNIQUE (ruche_id, horodatage) : anti-rejeu (UC-CY02)
--    CHECK : plages physiques valides (une trame absurde est refusée)
-- ---------------------------------------------------------------------------
CREATE TABLE mesure (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ruche_id         uuid NOT NULL CONSTRAINT mesure_ruche_fk REFERENCES ruche(id),
  horodatage       timestamptz NOT NULL,
  poids_kg         numeric(5,2) CHECK (poids_kg BETWEEN 0 AND 200),
  temp_int_c       numeric(4,1) CHECK (temp_int_c BETWEEN -20 AND 70),
  temp_ext_c       numeric(4,1) CHECK (temp_ext_c BETWEEN -20 AND 70),
  humidite_pct     smallint     CHECK (humidite_pct BETWEEN 0 AND 100),
  activite_sonore  numeric(3,2) CHECK (activite_sonore BETWEEN 0 AND 1),
  batterie_pct     smallint     CHECK (batterie_pct BETWEEN 0 AND 100),
  latitude         numeric(8,5) CHECK (latitude  BETWEEN -90  AND 90),   -- position reçue (UC-CY04)
  longitude        numeric(8,5) CHECK (longitude BETWEEN -180 AND 180),
  CONSTRAINT mesure_anti_rejeu UNIQUE (ruche_id, horodatage)
);

-- ---------------------------------------------------------------------------
-- 8. INSPECTION : une ruche, réalisée par une apicultrice
-- ---------------------------------------------------------------------------
CREATE TABLE inspection (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ruche_id         uuid NOT NULL CONSTRAINT inspection_ruche_fk       REFERENCES ruche(id),
  apicultrice_id   uuid NOT NULL CONSTRAINT inspection_apicultrice_fk REFERENCES apicultrice(id),
  date_inspection  date NOT NULL
                   CONSTRAINT inspection_date_plausible CHECK (date_inspection >= DATE '2020-01-01'),
  etat_colonie     text NOT NULL CHECK (etat_colonie IN ('bon', 'moyen', 'faible', 'morte')),
  reine_presente   boolean,
  observations     text,
  photo            text                       -- chemin du fichier, pas l'image elle-même
);

-- Pas d'inspection datée dans le futur. Pas de CHECK avec current_date :
-- PostgreSQL suppose qu'un CHECK donne toujours le même résultat pour la même
-- ligne (une ligne acceptée un jour pourrait être refusée à la restauration).
-- Le contrôle se fait donc à l'écriture, par un trigger.
CREATE OR REPLACE FUNCTION inspection_pas_dans_le_futur() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.date_inspection > current_date THEN
    RAISE EXCEPTION 'inspection datée du % : date dans le futur (aujourd''hui : %)',
          NEW.date_inspection, current_date
      USING ERRCODE = 'check_violation',
            HINT = 'une inspection s''enregistre le jour où elle est faite, ou après';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER inspection_pas_dans_le_futur
  BEFORE INSERT OR UPDATE OF date_inspection ON inspection
  FOR EACH ROW EXECUTE FUNCTION inspection_pas_dans_le_futur();

-- ---------------------------------------------------------------------------
-- 9. RÉCOLTE : déclarée par l'apicultrice, validée par un compte (coordinateur)
--    Deux CHECK de sécurité :
--      - une quantité est toujours positive
--      - une récolte « validee » a TOUJOURS un validateur et une date
--        (sinon : récolte validée sans qu'on sache par qui -> R de STRIDE)
-- ---------------------------------------------------------------------------
CREATE TABLE recolte (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ruche_id         uuid NOT NULL CONSTRAINT recolte_ruche_fk REFERENCES ruche(id),
  date_recolte     date NOT NULL,
  quantite_kg      numeric(6,2) NOT NULL,
  statut           text NOT NULL DEFAULT 'declaree'
                   CHECK (statut IN ('declaree', 'validee', 'ecart')),
  validee_par      uuid CONSTRAINT recolte_validee_par_fk REFERENCES utilisateur(id),
  date_validation  timestamptz,
  CONSTRAINT recolte_quantite_positive CHECK (quantite_kg > 0),
  CONSTRAINT recolte_validation_tracee CHECK (
    statut <> 'validee' OR (validee_par IS NOT NULL AND date_validation IS NOT NULL)
  )
);

-- ---------------------------------------------------------------------------
-- 10. ALERTE : déclenchée sur une ruche, avec un niveau de confiance
-- ---------------------------------------------------------------------------
CREATE TABLE alerte (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ruche_id          uuid NOT NULL CONSTRAINT alerte_ruche_fk REFERENCES ruche(id),
  type              text NOT NULL
                    CHECK (type IN ('essaimage', 'vol', 'capteur_silencieux',
                                    'stress_thermique', 'mortalite')),
  date_alerte       timestamptz NOT NULL DEFAULT now(),
  niveau_confiance  numeric(3,2) NOT NULL,
  statut            text NOT NULL DEFAULT 'ouverte'
                    CHECK (statut IN ('ouverte', 'en_cours', 'fermee')),
  CONSTRAINT alerte_confiance_bornee CHECK (niveau_confiance BETWEEN 0 AND 1)
);

-- ---------------------------------------------------------------------------
-- 11. INDEX DES CLÉS ÉTRANGÈRES
--     PostgreSQL indexe la cible d'une clé étrangère (clé primaire ou UNIQUE),
--     pas la colonne qui la référence. Sans index, supprimer ou modifier une
--     ligne parente parcourt toute la table fille, comme la jointure « les
--     ruches de ce site ». Une clé déjà en tête d'une clé primaire ou d'un
--     UNIQUE est couverte par son index, on n'en ajoute pas :
--       adhesion_apicultrice_fk    : PRIMARY KEY (apicultrice_id, cooperative_id)
--       utilisateur_apicultrice_fk : UNIQUE (apicultrice_id)
--       mesure_ruche_fk            : mesure_anti_rejeu UNIQUE (ruche_id, horodatage)
-- ---------------------------------------------------------------------------
CREATE INDEX cooperative_site_idx       ON cooperative (site_id);
CREATE INDEX apicultrice_site_idx       ON apicultrice (site_id);
CREATE INDEX ruche_site_idx             ON ruche (site_id);
CREATE INDEX ruche_apicultrice_site_idx ON ruche (apicultrice_id, site_id);
CREATE INDEX adhesion_cooperative_idx   ON adhesion (cooperative_id);
CREATE INDEX utilisateur_site_idx       ON utilisateur (site_id);
CREATE INDEX inspection_ruche_idx       ON inspection (ruche_id);
CREATE INDEX inspection_apicultrice_idx ON inspection (apicultrice_id);
CREATE INDEX recolte_ruche_idx          ON recolte (ruche_id);
CREATE INDEX recolte_validee_par_idx    ON recolte (validee_par);
CREATE INDEX alerte_ruche_idx           ON alerte (ruche_id);

-- Limite connue (à traiter au jour 2) : la base ne vérifie pas encore que
-- validee_par est bien un COORDINATEUR du site de la ruche. Un CHECK ne peut
-- pas lire une autre table : il faudra un trigger ou des droits par rôle.
