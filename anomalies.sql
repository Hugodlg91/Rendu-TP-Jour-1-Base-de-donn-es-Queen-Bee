-- anomalies.sql : anomalies de la table à plat, nettoyage et preuve sans perte
-- TP Jour 1, Lab 5 (étapes 5.1, 5.2 et 5.3)
-- Groupe : Praveen, Ugo, Hugo, Corentin
--
-- AVANT DE COMMENCER, dans le terminal, repartir d'un extrait propre (sans la clé ajoutée à l'étape 5.1) :
--   psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f plat.sql
--
-- Puis exécuter les commandes UNE PAR UNE, DANS L'ORDRE, dans le Query Tool.
-- Ordre complet du lab :
--   plat.sql -> anomalies.sql étape 5.1 -> migration_3nf.sql (refus)
--   -> anomalies.sql étape 5.2 (nettoyage) -> migration_3nf.sql (passe)
--   -> anomalies.sql étape 5.3 (preuve)
-- NE PAS relancer plat.sql entre 5.1 et 5.2 : les incohérences créées en 5.1
-- (un pays et un téléphone modifiés) sont justement celles qu'on retrouve en 5.2.
--
-- Les poids sont tirés au hasard par donnees.sql (random()) : les moyennes
-- ci-dessous changent à chaque rechargement de la base. Les comptes
-- (nombre de pays, de lignes) ne changent pas.


-- ===========================================================================
-- ÉTAPE 5.1 · PROVOQUER LES ANOMALIES
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Anomalie de MISE À JOUR
--    Le pays d'un site est recopié sur 144 lignes ; on n'en change qu'une.
-- ---------------------------------------------------------------------------

-- Enquête de référence : nombre de mesures et poids moyen par pays
SELECT pays, count(*) AS nb_mesures, round(avg(poids_kg), 2) AS poids_moyen
FROM extrait_plat
GROUP BY pays
ORDER BY pays;
--      pays      | nb_mesures | poids_moyen
-- ---------------+------------+-------------
--  Cameroun      |         96 |       37.69
--  Côte d'Ivoire |        144 |       37.27
--  Sénégal       |        288 |       37.49
-- (3 rows)
-- => 3 pays (attendu : 3)

-- Sur UNE seule ligne, « Sénégal » devient « Senegal » (commande imposée par le TP)
UPDATE extrait_plat SET pays = 'Senegal'
WHERE ruche_code = 'SN-KOLD-011'
  AND horodatage = (SELECT min(horodatage) FROM extrait_plat WHERE ruche_code = 'SN-KOLD-011');
-- UPDATE 1

-- Sur UNE AUTRE ligne, le téléphone d'Adjoua Kouassi change (même technique)
-- (+225 07 300 00 05 sur ses 95 autres lignes)
UPDATE extrait_plat SET telephone = '+225 07 300 00 99'
WHERE ruche_code = 'CI-YAMO-001'
  AND horodatage = (SELECT min(horodatage) FROM extrait_plat WHERE ruche_code = 'CI-YAMO-001');
-- UPDATE 1

-- On relance l'enquête
SELECT pays, count(*) AS nb_mesures, round(avg(poids_kg), 2) AS poids_moyen
FROM extrait_plat
GROUP BY pays
ORDER BY pays;
--      pays      | nb_mesures | poids_moyen
-- ---------------+------------+-------------
--  Cameroun      |         96 |       37.69
--  Côte d'Ivoire |        144 |       37.27
--  Senegal       |          1 |       41.13
--  Sénégal       |        287 |       37.48
-- (4 rows)
-- => 4 pays (attendu : 4). « Senegal » apparaît comme un quatrième pays :
--    le même fait (SN-KOLD est au Sénégal) a maintenant deux valeurs.

-- ---------------------------------------------------------------------------
-- 2. Anomalie de SUPPRESSION
--    Awa Diop (+221 77 100 00 02) n'a qu'une ruche : SN-CASA-021.
-- ---------------------------------------------------------------------------

-- Vérification : une seule ruche pour ce téléphone
SELECT ruche_code, count(*) AS nb_lignes
FROM extrait_plat
WHERE telephone = '+221 77 100 00 02'
GROUP BY ruche_code;
--  ruche_code  | nb_lignes
-- -------------+-----------
--  SN-CASA-021 |        48
-- (1 row)

BEGIN;
-- BEGIN

-- On veut seulement effacer les mesures de la ruche SN-CASA-021...
DELETE FROM extrait_plat WHERE ruche_code = 'SN-CASA-021';
-- DELETE 48

-- ... mais l'apicultrice disparaît avec elles
SELECT count(*) FROM extrait_plat WHERE telephone = '+221 77 100 00 02';
--  count
-- -------
--      0
-- (1 row)
-- => son téléphone a disparu (attendu) : plus aucune trace d'Awa Diop.

ROLLBACK;
-- ROLLBACK   (les 48 lignes sont restaurées)

-- ---------------------------------------------------------------------------
-- 3. Anomalie d'INSERTION
-- ---------------------------------------------------------------------------

ALTER TABLE extrait_plat ADD PRIMARY KEY (ruche_code, horodatage);
-- ALTER TABLE

-- Un nouveau site (Douala, Cameroun) sans ruche ni mesure
INSERT INTO extrait_plat (site_id, site_nom, pays)
VALUES ('CM-DOUA', 'Douala', 'Cameroun');
-- ERROR:  null value in column "ruche_code" of relation "extrait_plat" violates not-null constraint
-- DETAIL:  Failing row contains (null, CM-DOUA, Douala, Cameroun, null, null, null, null, null, null).
-- => refus (attendu) : impossible d'enregistrer un site tant qu'il n'a pas de mesure.


-- ===========================================================================
-- Ici, dans le terminal : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f migration_3nf.sql
-- => REFUS attendu et obtenu :
--    ERROR:  duplicate key value violates unique constraint "site_pkey"
--    DETAIL:  Key (site_id)=(SN-KOLD) already exists.
--    (sortie complète collée en fin de migration_3nf.sql)
-- ===========================================================================


-- ===========================================================================
-- ÉTAPE 5.2 · NETTOYAGE (dans le Query Tool)
-- On cherche, pour CHAQUE dépendance du lab 4, un déterminant qui aurait
-- plusieurs valeurs : GROUP BY déterminant HAVING count(DISTINCT colonne) > 1
-- ===========================================================================

-- DF site_id -> pays
SELECT site_id, array_agg(DISTINCT pays) AS pays
FROM extrait_plat
GROUP BY site_id
HAVING count(DISTINCT pays) > 1;
--  site_id |       pays
-- ---------+-------------------
--  SN-KOLD | {Senegal,Sénégal}
-- (1 row)

-- DF site_id -> site_nom
SELECT site_id, array_agg(DISTINCT site_nom) AS site_nom
FROM extrait_plat
GROUP BY site_id
HAVING count(DISTINCT site_nom) > 1;
--  site_id | site_nom
-- ---------+----------
-- (0 rows)

-- DF ruche_code -> site_id
SELECT ruche_code, array_agg(DISTINCT site_id) AS site_id
FROM extrait_plat
GROUP BY ruche_code
HAVING count(DISTINCT site_id) > 1;
--  ruche_code | site_id
-- ------------+---------
-- (0 rows)

-- DF ruche_code -> telephone
-- Le téléphone modifié est NOUVEAU (+225 07 300 00 99) : il n'apparaît que sur
-- une ligne, donc telephone -> apicultrice n'est PAS contredit (ce numéro n'a
-- qu'une apicultrice). C'est ruche_code -> telephone qui l'est : la ruche
-- CI-YAMO-001 a maintenant deux téléphones.
SELECT ruche_code, array_agg(DISTINCT telephone) AS telephone
FROM extrait_plat
GROUP BY ruche_code
HAVING count(DISTINCT telephone) > 1;
--  ruche_code  |                 telephone
-- -------------+-------------------------------------------
--  CI-YAMO-001 | {"+225 07 300 00 05","+225 07 300 00 99"}
-- (1 row)

-- DF telephone -> apicultrice, cooperative (aucun conflit, voir ci-dessus)
SELECT telephone, array_agg(DISTINCT apicultrice) AS apicultrice,
       array_agg(DISTINCT cooperative) AS cooperative
FROM extrait_plat
GROUP BY telephone
HAVING count(DISTINCT apicultrice) > 1 OR count(DISTINCT cooperative) > 1;
--  telephone | apicultrice | cooperative
-- -----------+-------------+-------------
-- (0 rows)

-- (La DF ruche_code, horodatage -> poids_kg, temp_int_c est garantie par la
--  PRIMARY KEY ajoutée en 5.1 : pas de doublon possible.)

-- Quelle est la bonne valeur ? La valeur majoritaire.
SELECT site_id, pays, count(*) AS nb_lignes
FROM extrait_plat
WHERE site_id = 'SN-KOLD'
GROUP BY site_id, pays
ORDER BY nb_lignes DESC;
--  site_id |  pays   | nb_lignes
-- ---------+---------+-----------
--  SN-KOLD | Sénégal |       143
--  SN-KOLD | Senegal |         1
-- (2 rows)

SELECT ruche_code, telephone, count(*) AS nb_lignes
FROM extrait_plat
WHERE ruche_code = 'CI-YAMO-001'
GROUP BY ruche_code, telephone
ORDER BY nb_lignes DESC;
--  ruche_code  |     telephone     | nb_lignes
-- -------------+-------------------+-----------
--  CI-YAMO-001 | +225 07 300 00 05 |        47
--  CI-YAMO-001 | +225 07 300 00 99 |         1
-- (2 rows)

-- Corrections : on garde la valeur majoritaire
UPDATE extrait_plat SET pays = 'Sénégal'
WHERE site_id = 'SN-KOLD' AND pays = 'Senegal';
-- UPDATE 1

UPDATE extrait_plat SET telephone = '+225 07 300 00 05'
WHERE ruche_code = 'CI-YAMO-001' AND telephone = '+225 07 300 00 99';
-- UPDATE 1

-- Contrôle : plus aucun conflit
SELECT site_id, array_agg(DISTINCT pays) AS pays
FROM extrait_plat
GROUP BY site_id
HAVING count(DISTINCT pays) > 1;
-- (0 rows)

SELECT ruche_code, array_agg(DISTINCT telephone) AS telephone
FROM extrait_plat
GROUP BY ruche_code
HAVING count(DISTINCT telephone) > 1;
-- (0 rows)


-- ===========================================================================
-- Ici, dans le terminal : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f migration_3nf.sql
-- => la migration PASSE : INSERT 0 4 / INSERT 0 8 / INSERT 0 11 / INSERT 0 528 / COMMIT
-- (la PRIMARY KEY ajoutée à extrait_plat en 5.1 ne gêne pas la migration)
-- ===========================================================================

-- Vérification des comptes
SELECT (SELECT count(*) FROM norm.site)        AS sites,
       (SELECT count(*) FROM norm.apicultrice) AS apicultrices,
       (SELECT count(*) FROM norm.ruche)       AS ruches,
       (SELECT count(*) FROM norm.mesure)      AS mesures;
--  sites | apicultrices | ruches | mesures
-- -------+--------------+--------+---------
--      4 |            8 |     11 |     528
-- (1 row)
-- => attendu : 4 sites, 8 apicultrices, 11 ruches, 528 mesures. Conforme.


-- ===========================================================================
-- ÉTAPE 5.3 · PROUVER QUE RIEN N'EST PERDU (dans le Query Tool)
-- (La vue est supprimée par DROP SCHEMA norm CASCADE si on relance la
--  migration : il suffit alors de la recréer.)
-- ===========================================================================

-- 1. Recomposer la table : mêmes colonnes, même ordre que extrait_plat
CREATE VIEW norm.reconstruit AS
SELECT m.ruche_code, s.site_id, s.site_nom, s.pays,
       a.apicultrice, a.telephone, a.cooperative,
       m.horodatage, m.poids_kg, m.temp_int_c
FROM norm.mesure m
JOIN norm.ruche r       USING (ruche_code)
JOIN norm.site s        ON s.site_id = r.site_id
JOIN norm.apicultrice a ON a.telephone = r.telephone;
-- CREATE VIEW

SELECT count(*) FROM norm.reconstruit;
--  count
-- -------
--    528
-- (1 row)

-- Comparaison dans les deux sens
(SELECT * FROM extrait_plat EXCEPT SELECT * FROM norm.reconstruit)
UNION ALL
(SELECT * FROM norm.reconstruit EXCEPT SELECT * FROM extrait_plat);
--  ruche_code | site_id | site_nom | pays | apicultrice | telephone | cooperative | horodatage | poids_kg | temp_int_c
-- ------------+---------+----------+------+-------------+-----------+-------------+------------+----------+------------
-- (0 rows)
-- => 0 ligne (attendu) : la décomposition est sans perte.

-- 2. Attaques rejouées
-- a) Un second pays pour un site existant : refusé
INSERT INTO norm.site VALUES ('SN-KOLD', 'Kolda', 'Senegal');
-- ERROR:  duplicate key value violates unique constraint "site_pkey"
-- DETAIL:  Key (site_id)=(SN-KOLD) already exists.

-- b) Un site sans ruche : accepté (entre BEGIN et ROLLBACK pour garder la base propre)
BEGIN;
-- BEGIN
INSERT INTO norm.site VALUES ('CM-DOUA', 'Douala', 'Cameroun');
-- INSERT 0 1
SELECT * FROM norm.site ORDER BY site_id;
--  site_id |   site_nom   |     pays
-- ---------+--------------+---------------
--  CI-YAMO | Yamoussoukro | Côte d'Ivoire
--  CM-BAFO | Bafoussam    | Cameroun
--  CM-DOUA | Douala       | Cameroun
--  SN-CASA | Casamance    | Sénégal
--  SN-KOLD | Kolda        | Sénégal
-- (5 rows)
ROLLBACK;
-- ROLLBACK

-- 3. L'enquête par pays sur les tables norm
SELECT s.pays, count(*) AS nb_mesures, round(avg(m.poids_kg), 2) AS poids_moyen
FROM norm.mesure m
JOIN norm.ruche r USING (ruche_code)
JOIN norm.site s  ON s.site_id = r.site_id
GROUP BY s.pays
ORDER BY s.pays;
--      pays      | nb_mesures | poids_moyen
-- ---------------+------------+-------------
--  Cameroun      |         96 |       37.69
--  Côte d'Ivoire |        144 |       37.27
--  Sénégal       |        288 |       37.49
-- (3 rows)
-- => de nouveau 3 pays (attendu), mêmes chiffres que l'enquête de référence.
