-- contraintes.sql : confronter les dépendances aux données, rendre les logins uniques
-- TP Jour 1, Lab 4 (étapes 4.3 et 4.4)
-- Groupe : Praveen, Ugo, Hugo, Corentin
--
-- ATTENTION : ce fichier MODIFIE les données (étape 4.4 : UPDATE des logins,
-- ajout d'une contrainte et d'un index). Il s'exécute UNE SEULE FOIS, requête
-- par requête, DANS L'ORDRE (Query Tool, F5 sur chaque requête), comme le
-- demande le TP. Les commandes 2 et 6 de l'étape 4.4 doivent échouer : c'est
-- le résultat attendu.
--
-- Pour repartir de zéro (base dans l'état du jeu d'essai) :
--   psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f schema.sql
--   psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f donnees.sql
--   psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f plat.sql
--
-- Prérequis : extrait_plat créée par plat.sql (528 lignes).
-- Les poids et températures sont aléatoires (donnees.sql) : ils changent à
-- chaque rechargement, mais aucun résultat collé ci-dessous n'en dépend.


-- ===========================================================================
-- ÉTAPE 4.3 · Confronter les dépendances aux données
-- Modèle : SELECT X FROM extrait_plat GROUP BY X HAVING count(DISTINCT Y) > 1;
-- Une ligne affichée = une valeur de X associée à deux valeurs de Y = DF fausse.
-- ===========================================================================

-- DF 1 : site_id -> site_nom, pays
SELECT site_id, count(DISTINCT (site_nom, pays)) AS versions
FROM extrait_plat
GROUP BY site_id
HAVING count(DISTINCT (site_nom, pays)) > 1;
--  site_id | versions
-- ---------+----------
-- (0 rows)

-- DF 2 : ruche_code -> site_id, telephone
SELECT ruche_code, count(DISTINCT (site_id, telephone)) AS versions
FROM extrait_plat
GROUP BY ruche_code
HAVING count(DISTINCT (site_id, telephone)) > 1;
--  ruche_code | versions
-- ------------+----------
-- (0 rows)

-- DF 3 : telephone -> apicultrice, cooperative
-- (vraie dans le jeu d'essai seulement : une adhésion par apicultrice, voir dependances.md)
SELECT telephone, count(DISTINCT (apicultrice, cooperative)) AS versions
FROM extrait_plat
GROUP BY telephone
HAVING count(DISTINCT (apicultrice, cooperative)) > 1;
--  telephone | versions
-- -----------+----------
-- (0 rows)

-- DF 4 : ruche_code, horodatage -> poids_kg, temp_int_c
SELECT ruche_code, horodatage, count(DISTINCT (poids_kg, temp_int_c)) AS versions
FROM extrait_plat
GROUP BY ruche_code, horodatage
HAVING count(DISTINCT (poids_kg, temp_int_c)) > 1;
--  ruche_code | horodatage | versions
-- ------------+------------+----------
-- (0 rows)

-- Dépendance ÉCARTÉE (voir dependances.md) : telephone -> site_id
-- 0 ligne ici, mais ce n'est pas une règle métier (transhumance, hypothèse du lab 1)
SELECT telephone, count(DISTINCT site_id) AS nb_sites
FROM extrait_plat
GROUP BY telephone
HAVING count(DISTINCT site_id) > 1;
--  telephone | nb_sites
-- -----------+----------
-- (0 rows)

-- Fausse DF : apicultrice -> telephone (« le nom donne le téléphone »)
SELECT apicultrice, count(DISTINCT telephone) AS nb_telephones
FROM extrait_plat
GROUP BY apicultrice
HAVING count(DISTINCT telephone) > 1;
--  apicultrice  | nb_telephones
-- --------------+---------------
--  Aminata Diop |             2
-- (1 row)
-- -> Le nom ne détermine pas la personne : DF fausse (deux homonymes).


-- ===========================================================================
-- ÉTAPE 4.4 · Rendre les logins uniques
-- À exécuter UNE PAR UNE, DANS L'ORDRE.
-- ===========================================================================

-- Commande 1 : logins en double, et à qui ils appartiennent
SELECT u.login, a.nom, a.telephone, u.site_id
FROM utilisateur u
LEFT JOIN apicultrice a ON a.id = u.apicultrice_id
WHERE u.login IN (SELECT login FROM utilisateur GROUP BY login HAVING count(*) > 1)
ORDER BY u.login, a.telephone;
--  login  |     nom      |     telephone     | site_id
-- --------+--------------+-------------------+---------
--  a.diop | Aminata Diop | +221 77 100 00 01 | SN-CASA
--  a.diop | Awa Diop     | +221 77 100 00 02 | SN-CASA
--  a.diop | Aminata Diop | +221 77 200 00 03 | SN-KOLD
-- (3 rows)

-- Commande 2 : poser le login unique -> refus attendu
ALTER TABLE utilisateur ADD CONSTRAINT utilisateur_login_unique UNIQUE (login);
-- ERROR:  could not create unique index "utilisateur_login_unique"
-- DETAIL:  Key (login)=(a.diop) is duplicated.

-- Commande 3 : un login différent par personne.
-- Chaque compte est retrouvé par le téléphone de l'apicultrice (unique),
-- jamais par le nom (ambigu). On renomme les deux Aminata Diop ;
-- Awa Diop garde « a.diop » (il n'y a plus de doublon).
UPDATE utilisateur u SET login = 'aminata.diop.casa'
FROM apicultrice a
WHERE a.id = u.apicultrice_id AND a.telephone = '+221 77 100 00 01';
-- UPDATE 1

UPDATE utilisateur u SET login = 'aminata.diop.kold'
FROM apicultrice a
WHERE a.id = u.apicultrice_id AND a.telephone = '+221 77 200 00 03';
-- UPDATE 1

-- Commande 4 : la même contrainte qu'en 2 -> acceptée
ALTER TABLE utilisateur ADD CONSTRAINT utilisateur_login_unique UNIQUE (login);
-- ALTER TABLE

-- Commande 5 : le piège des majuscules. « A.Diop » est différent de « a.diop »
-- pour la contrainte UNIQUE -> accepté. Rôle gestionnaire, sans site ni
-- apicultrice (le CHECK interdit un rôle 'apicultrice' sans apicultrice).
INSERT INTO utilisateur (login, role) VALUES ('A.Diop', 'gestionnaire');
-- INSERT 0 1

DELETE FROM utilisateur WHERE login = 'A.Diop';
-- DELETE 1

-- Commande 6 : index unique insensible à la casse, puis de nouveau A.Diop -> refus
CREATE UNIQUE INDEX utilisateur_login_ci ON utilisateur (lower(login));
-- CREATE INDEX

INSERT INTO utilisateur (login, role) VALUES ('A.Diop', 'gestionnaire');
-- ERROR:  duplicate key value violates unique constraint "utilisateur_login_ci"
-- DETAIL:  Key (lower(login))=(a.diop) already exists.

-- Vérification (facultative) : les 10 comptes après correction
SELECT u.login, u.role, u.site_id, a.nom, a.telephone
FROM utilisateur u
LEFT JOIN apicultrice a ON a.id = u.apicultrice_id
ORDER BY u.login;
--        login       |     role     | site_id |      nom       |     telephone
-- -------------------+--------------+---------+----------------+-------------------
--  a.diop            | apicultrice  | SN-CASA | Awa Diop       | +221 77 100 00 02
--  a.kone            | apicultrice  | CI-YAMO | Aya Kone       | +225 07 300 00 06
--  a.kouassi         | apicultrice  | CI-YAMO | Adjoua Kouassi | +225 07 300 00 05
--  admin             | admin        |         |                |
--  aminata.diop.casa | apicultrice  | SN-CASA | Aminata Diop   | +221 77 100 00 01
--  aminata.diop.kold | apicultrice  | SN-KOLD | Aminata Diop   | +221 77 200 00 03
--  b.ngono           | apicultrice  | CM-BAFO | Brigitte Ngono | +237 6 400 00 07
--  coord.casa        | coordinateur | SN-CASA |                |
--  e.fotso           | apicultrice  | CM-BAFO | Esther Fotso   | +237 6 400 00 08
--  m.ba              | apicultrice  | SN-KOLD | Mariama Ba     | +221 77 200 00 04
-- (10 rows)


-- ===========================================================================
-- STRIDE : que permet un login partagé (trois comptes « a.diop ») ?
-- ---------------------------------------------------------------------------
-- S (Spoofing / usurpation) : à la connexion, « a.diop » ne désigne pas une
--   seule personne ; l'application peut ouvrir la session d'une autre
--   apicultrice, qui agit alors sous une identité qui n'est pas la sienne.
-- R (Repudiation / répudiation) : les journaux enregistrent « a.diop » ;
--   impossible de prouver laquelle des trois a déclaré une récolte ou modifié
--   une inspection. Chacune peut nier.
-- I (Information disclosure / fuite) : une apicultrice voit les données de
--   l'autre (ruches, positions GPS, téléphone, récoltes), donc des données
--   personnelles et sensibles (UC-CY04 vol de ruches).
-- E (Elevation of privilege), possible : si les comptes homonymes n'ont pas les
--   mêmes droits (site, rôle), se connecter sur le mauvais compte donne des
--   droits sur un site qui n'est pas le sien.
-- ===========================================================================
