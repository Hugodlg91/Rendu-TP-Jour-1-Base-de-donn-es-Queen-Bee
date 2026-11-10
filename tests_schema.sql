-- tests_schema.sql : étape 2.5, essayer de casser la base Queen Bee (TP Jour 1, Lab 2)
-- Groupe : Praveen, Ugo, Hugo, Corentin
-- Lancement SANS ON_ERROR_STOP (les erreurs sont voulues) :
--   psql -U postgres -d queenbee -f tests_schema.sql
--
-- Aucune trace laissée : les tests 1, 2, 3, 6, 7 (essai), 8 et 9 (deux refus) sont
-- refusés (rien ne change), les tables des tests 4 et 5 sont supprimées en fin de
-- test, et l'inspection acceptée du test 9 est annulée par ROLLBACK.
-- Les UUID affichés dans les messages changent à chaque exécution.

-- Test 1 : une ruche dont l'apicultrice n'existe pas. Attendu : refus
INSERT INTO ruche (code, latitude, longitude, date_installation, site_id, apicultrice_id)
VALUES ('SN-CASA-777', 12.5, -16.2, '2027-03-14', 'SN-CASA', gen_random_uuid());
-- Obtenu :
-- ERROR:  insert or update on table "ruche" violates foreign key constraint "ruche_apicultrice_fk"
-- DETAIL:  Key (apicultrice_id, site_id)=(d0d03b0a-e2fd-4e8b-a143-a0ddf14dc4e3, SN-CASA) is not present in table "apicultrice".
-- (l'UUID affiché change à chaque exécution ; la clé est composée depuis la
--  correction 4 : le message cite le couple apicultrice, site)
-- Test 2 : supprimer une apicultrice qui a des ruches. Attendu : refus
DELETE FROM apicultrice WHERE telephone = '+221 77 100 00 01';
-- Obtenu :
-- ERROR:  update or delete on table "apicultrice" violates foreign key constraint "ruche_apicultrice_fk" on table "ruche"
-- DETAIL:  Key (id, site_id)=(4d4cb237-4f5e-48d0-82ba-fece79bf8a6e, SN-CASA) is still referenced from table "ruche".
-- Test 3 : une ruche sans apicultrice. Attendu : refus
INSERT INTO ruche (code, latitude, longitude, date_installation, site_id)
VALUES ('SN-CASA-778', 12.5, -16.2, '2027-03-14', 'SN-CASA');
-- Obtenu :
-- ERROR:  null value in column "apicultrice_id" of relation "ruche" violates not-null constraint
-- DETAIL:  Failing row contains (c385dd5e-b754-4979-b1ce-06d23698feaf, SN-CASA-778, 12.50000, -16.20000, 2027-03-14, SN-CASA, null).
-- (PostgreSQL 16 nomme ici la colonne et la règle NOT NULL, pas un nom de contrainte ; l'UUID change à chaque exécution)
-- Test 4 : table SANS clé étrangère : ruche orpheline puis jointure. Attendu : accepté, puis 0 ligne
DROP TABLE IF EXISTS ruche_sans_fk;
CREATE TABLE ruche_sans_fk (code text, apicultrice_id uuid);
INSERT INTO ruche_sans_fk VALUES ('ORPHELINE-001', gen_random_uuid());
SELECT r.code, a.nom
FROM ruche_sans_fk r JOIN apicultrice a ON a.id = r.apicultrice_id;
DROP TABLE ruche_sans_fk;
-- Obtenu : le DROP, le CREATE et l'INSERT passent (INSERT 0 1) : rien n'empêche l'orpheline ; puis
--  code | nom
-- ------+-----
-- (0 rows)
-- L'orpheline est invisible dans toute jointure : sans clé étrangère, la base ne protège rien.
-- Test 5 : table avec id serial : 3 insertions, affichage. Attendu : 1, 2, 3 (devinable)
DROP TABLE IF EXISTS test_serial;
CREATE TABLE test_serial (id serial PRIMARY KEY, libelle text);
INSERT INTO test_serial (libelle) VALUES ('a'), ('b'), ('c');
SELECT id, libelle FROM test_serial ORDER BY id;
DROP TABLE test_serial;
-- Obtenu :
--  id | libelle
-- ----+---------
--   1 | a
--   2 | b
--   3 | c
-- (3 rows)
-- Un attaquant qui connaît l'id 3 essaie 4, 5, 6... : c'est l'énumération. D'où les UUID.
-- Test 6 : une mesure déjà reçue (même ruche, même instant). Attendu : refus
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temp_int_c)
SELECT ruche_id, horodatage, 30.0, 50 FROM mesure ORDER BY id LIMIT 1;
-- Obtenu :
-- ERROR:  duplicate key value violates unique constraint "mesure_anti_rejeu"
-- DETAIL:  Key (ruche_id, horodatage)=(ae46c5bb-e8da-4a66-a3a3-95396b5ef712, 2027-03-14 00:00:00+00) already exists.
-- (l'UUID affiché change à chaque exécution)
-- Test 7 : ruches dont le site diffère de celui de leur apicultrice. Attendu : 0 ligne
-- (hypothèse du lab 1 : une ruche est sur le site de son apicultrice ; une
--  transhumance sera une entité à part, voir annotations.md, question 4)
SELECT r.code, r.site_id AS site_ruche, a.site_id AS site_apicultrice
FROM ruche r JOIN apicultrice a ON a.id = r.apicultrice_id
WHERE r.site_id <> a.site_id;
-- Obtenu :
--  code | site_ruche | site_apicultrice
-- ------+------------+------------------
-- (0 rows)
-- 0 ligne, et c'est désormais IMPOSSIBLE autrement (correction 4) : la clé
-- étrangère composée ruche_apicultrice_fk (apicultrice_id, site_id) -> apicultrice
-- (id, site_id) refuse une ruche hors du site de son apicultrice. Essai :
INSERT INTO ruche (code, latitude, longitude, date_installation, site_id, apicultrice_id)
VALUES ('SN-KOLD-779', 12.9, -14.9, '2027-03-14', 'SN-KOLD',
        (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 01'));
-- Obtenu (Aminata Diop de SN-CASA, ruche déclarée à SN-KOLD) :
-- ERROR:  insert or update on table "ruche" violates foreign key constraint "ruche_apicultrice_fk"
-- DETAIL:  Key (apicultrice_id, site_id)=(4d4cb237-4f5e-48d0-82ba-fece79bf8a6e, SN-KOLD) is not present in table "apicultrice".
-- (l'UUID affiché change à chaque exécution)
-- Test 8 : récolte « declaree » passée à « validee » sans validateur. Attendu : refus
UPDATE recolte SET statut = 'validee' WHERE statut = 'declaree';
-- Obtenu :
-- ERROR:  new row for relation "recolte" violates check constraint "recolte_validation_tracee"
-- DETAIL:  Failing row contains (88196649-3eb6-4634-b679-60e393890ae5, 7ee148ee-2ddb-4f26-b865-7fddb233cd2d, 2027-03-13, 9.50, validee, null, null).
-- (les UUID changent à chaque exécution)
-- Test 9 : une inspection datée de 2099, puis de 2019, puis d'aujourd'hui (correction 5).
-- Attendu : 2099 refusée (trigger), 2019 refusée (CHECK), aujourd'hui acceptée,
-- le tout dans des transactions annulées
BEGIN;
INSERT INTO inspection (ruche_id, apicultrice_id, date_inspection, etat_colonie)
SELECT id, apicultrice_id, DATE '2099-03-14', 'bon' FROM ruche WHERE code = 'SN-CASA-021';
ROLLBACK;
-- Obtenu :
-- ERROR:  inspection datée du 2099-03-14 : date dans le futur (aujourd'hui : 2026-11-10)
-- HINT:  une inspection s'enregistre le jour où elle est faite, ou après
-- (la date du jour change ; un CHECK avec current_date aurait été faux : voir schema.sql)
BEGIN;
INSERT INTO inspection (ruche_id, apicultrice_id, date_inspection, etat_colonie)
SELECT id, apicultrice_id, DATE '2019-12-31', 'bon' FROM ruche WHERE code = 'SN-CASA-021';
ROLLBACK;
-- Obtenu :
-- ERROR:  new row for relation "inspection" violates check constraint "inspection_date_plausible"
BEGIN;
INSERT INTO inspection (ruche_id, apicultrice_id, date_inspection, etat_colonie)
SELECT id, apicultrice_id, current_date, 'bon' FROM ruche WHERE code = 'SN-CASA-021';
SELECT count(*) AS inspections FROM inspection;
ROLLBACK;
-- Obtenu : INSERT 0 1, puis 7 inspections (les 6 du jeu d'essai + celle du jour),
-- puis ROLLBACK : il en reste 6.

-- ---------------------------------------------------------------------------
-- Question du TP : un UUID suffit-il à protéger la ruche d'une autre apicultrice ?
-- ---------------------------------------------------------------------------
-- Non. L'UUID empêche de DEVINER ou d'énumérer les identifiants (contrairement
-- à l'id serial du test 5 : 1, 2, 3...), mais ce n'est pas un contrôle d'accès.
-- Un UUID qui fuit (dans une URL, un log, un historique de navigateur, une
-- réponse d'API) reste utilisable par quiconque le possède. Si l'application
-- ne vérifie pas que cette ruche appartient bien à l'apicultrice connectée,
-- elle sert la ruche d'une autre : c'est l'IDOR (Insecure Direct Object
-- Reference). Il faut donc vérifier les droits côté application ou côté base
-- (RBAC, rôles et privilèges, Row Level Security), à chaque requête.
--
-- ---------------------------------------------------------------------------
-- Testez-vous · Lab 2 (réponses courtes)
-- ---------------------------------------------------------------------------
-- 1. Association 1,1 - 0,n : la clé étrangère se met dans la table du côté 1,1
--    (celle qui a UN seul partenaire), par ex. ruche.apicultrice_id.
-- 2. Parce qu'une ligne de la table d'association est identifiée par le COUPLE
--    des deux entités liées : ni l'une ni l'autre seule n'est unique (une
--    apicultrice adhère à plusieurs coopératives et inversement). Le couple
--    interdit aussi les doublons (une seule adhésion par couple).
-- 3. Elle interdit d'enregistrer deux mesures pour la même ruche au même
--    instant : protection anti-rejeu (UC-CY02), un message rejoué est refusé
--    (test 6) et les relevés ne sont pas dupliqués.
--    Limite : l'UNIQUE ne refuse que le rejeu À L'IDENTIQUE. Une ancienne trame
--    renvoyée avec un horodatage modifié (même +1 µs) est acceptée ; une trame
--    datée dans le futur bloque la vraie trame de cet instant et devient la
--    « dernière pesée » de v_ruche_coordinateur. Un vrai anti-rejeu (UC-CY02)
--    demande un compteur monotone et une signature (HMAC) du capteur vérifiés à
--    l'ingestion, et un contrôle de plausibilité de l'horodatage.
-- 4. Parce qu'une clé étrangère ne peut pointer que vers une table qui existe
--    déjà : site est référencée par ruche, donc créée avant (ordre de
--    dépendance ; sinon CREATE TABLE échoue).

-- ---------------------------------------------------------------------------
-- Limites connues du schéma (révélées par les tests, à traiter au jour 2)
-- ---------------------------------------------------------------------------
-- 1. validee_par n'est pas forcément un COORDINATEUR du site de la ruche
--    (un CHECK ne lit pas une autre table : trigger ou droits par rôle).
--    Une partie se fait pourtant sans trigger, par clés étrangères composites,
--    comme pour la limite 2 : colonne recolte.site_id avec FK (ruche_id, site_id)
--    vers ruche (id, site_id), et FK (validee_par, validateur_role, site_id) vers
--    utilisateur (id, role, site_id), où validateur_role est une colonne générée
--    valant 'coordinateur' quand validee_par n'est pas NULL. Jour 2 :
--      ALTER TABLE ruche       ADD CONSTRAINT ruche_id_site_uq UNIQUE (id, site_id);
--      ALTER TABLE utilisateur ADD CONSTRAINT utilisateur_id_role_site_uq UNIQUE (id, role, site_id);
--      ALTER TABLE recolte ADD COLUMN site_id text,  -- rempli depuis la ruche, puis NOT NULL
--        ADD COLUMN validateur_role text GENERATED ALWAYS AS
--          (CASE WHEN validee_par IS NOT NULL THEN 'coordinateur' END) STORED;
--      ALTER TABLE recolte
--        ADD CONSTRAINT recolte_ruche_site_fk FOREIGN KEY (ruche_id, site_id) REFERENCES ruche (id, site_id),
--        ADD CONSTRAINT recolte_coord_site_fk FOREIGN KEY (validee_par, validateur_role, site_id)
--          REFERENCES utilisateur (id, role, site_id);
--    (pour une récolte déclarée, validateur_role vaut NULL : une clé étrangère
--     composite avec une colonne NULL n'est pas vérifiée en MATCH SIMPLE, ce qui
--     est voulu ici)
--    Effet de bord : tant qu'une ruche a des récoltes, cette FK interdit de
--    changer son site de rattachement (depuis la correction 4, une transhumance
--    ne le change plus). Avec ON UPDATE CASCADE, le site des
--    récoltes suivrait la ruche, et les récoltes déjà validées bloqueraient
--    le déplacement (leur coordinateur est celui de l'ancien site). Si le site
--    de la récolte doit rester celui du jour de la récolte : pas de FK vers
--    ruche, site_id rempli par un trigger BEFORE INSERT.
-- 2. utilisateur.site_id recopie, pour un compte apicultrice, le site de son
--    apicultrice, sans que la base impose l'égalité : un compte peut être
--    rattaché à un autre site et lire ses ruches (I, E). Jour 2 :
--      (apicultrice_id_site_uq UNIQUE (id, site_id) existe déjà depuis la
--       correction 4 : c'est la cible de ruche_apicultrice_fk)
--      ALTER TABLE utilisateur ADD CONSTRAINT utilisateur_apicultrice_site_fk
--        FOREIGN KEY (apicultrice_id, site_id) REFERENCES apicultrice (id, site_id);
--    (15e clé étrangère : non posée aujourd'hui pour garder le modèle du jour 1)
-- 3. Traçabilité de la récolte incomplète (menace R) : un statut « ecart » n'est
--    pas imputé (qui, quand ?) ; date_validation peut précéder date_recolte ; une
--    récolte validée reste modifiable, et sa validation effaçable, sans trace.
--    Jour 2 : un trigger qui fige les récoltes validées, une table de journal
--    (audit), et :
--      ALTER TABLE recolte ADD CONSTRAINT recolte_statut_coherent
--        CHECK ((statut = 'declaree') = (validee_par IS NULL)
--               AND (validee_par IS NULL) = (date_validation IS NULL));
--      ALTER TABLE recolte ADD CONSTRAINT recolte_validation_apres_recolte
--        CHECK (date_validation IS NULL OR (date_validation AT TIME ZONE 'UTC')::date >= date_recolte);
--    (premier CHECK : « declaree » si et seulement si pas de validateur, et
--     validateur si et seulement si date de validation ; aujourd'hui une
--     « declaree » peut encore porter un validateur. Il faut d'abord donner un
--     validateur et une date à la récolte « ecart » de donnees.sql. Second
--     CHECK : un simple ::date dépendrait du fuseau de la session, d'où le
--     passage par UTC.)
-- 4. Horodatage des mesures non contrôlé (trame future acceptée) : contrôle
--    « pas dans le futur » dans un trigger BEFORE INSERT (un CHECK avec now()
--    n'est pas déterministe ; le jeu d'essai est d'ailleurs daté de 2027).
--    Une partie est déclarative dès maintenant :
--      ALTER TABLE mesure ADD CONSTRAINT mesure_horodatage_fini
--        CHECK (isfinite(horodatage) AND horodatage >= TIMESTAMPTZ '2025-01-01 00:00+00');
--    refuse les trames datées 'infinity' (aujourd'hui acceptées : elles deviennent
--    la « dernière pesée » de la vue de requetes.sql) ; seul le « pas dans le
--    futur » demande un trigger. Une trame entièrement vide (seuls ruche_id et
--    horodatage sont NOT NULL) occupe aussi le créneau anti-rejeu.
--    Jour 2 : CHECK (num_nonnulls(poids_kg, temp_int_c, temp_ext_c, humidite_pct, activite_sonore, batterie_pct) > 0).
--    À l'ingestion,
--    imposer un horodatage avec décalage explicite : sans décalage, il est
--    interprété dans le fuseau de la session.
-- 5. Position GPS des mesures facultative : un capteur compromis qui n'envoie
--    plus de position échappe à la détection de vol (UC-CY04). Jour 2 :
--    latitude/longitude NOT NULL, voire un CHECK de zone géographique.
-- 6. Une inspection peut être saisie par n'importe quelle apicultrice, même d'un
--    autre site (le lab 1 suppose seulement une apicultrice du site de la ruche) :
--    contrôle par trigger ou RLS. Les deux CHECK de
--    utilisateur (cohérence rôle / apicultrice / site) n'ont pas de nom
--    explicite : à nommer au jour 2 (schema.sql est figé au jour 1, hors corrections
--    demandées par la prof : RENDU.md, section 7).
-- 7. L'index utilisateur_login_ci ne canonicalise pas le login (espace finale,
--    lettre cyrillique « а » acceptées). Jour 2 :
--      CHECK (login ~ '^[a-z0-9._@-]+$')
--    (à ne pas poser avant la commande 5 de contraintes.sql : il casserait la
--     démonstration imposée « A.Diop accepté »)
-- 8. Sécurité (RGPD art. 32) : l'algorithme de hachage attendu pour mot_de_passe_hash n'est précisé
--    nulle part (argon2id ou bcrypt), à fixer côté application.
--    Corrigé (correction 2) : la colonne est NOT NULL et le CHECK
--    utilisateur_hache_bcrypt impose le format bcrypt ; par défaut, le haché d'un
--    secret aléatoire inconnu (compte à activer par réinitialisation).
