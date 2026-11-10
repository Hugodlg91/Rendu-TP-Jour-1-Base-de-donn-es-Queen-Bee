-- donnees.sql : jeu d'essai Queen Bee (TP Jour 1, Lab 2, étape 2.3)
-- Groupe : Praveen, Ugo, Hugo, Corentin
-- Lancement (après schema.sql) :
--   psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f donnees.sql
--
-- Tout le fichier est dans une transaction : tout passe, ou rien ne passe.
-- Les tables sont remplies dans l'ordre de leur création.
-- On n'écrit jamais les id : la base les génère.
--
-- Résultat attendu : 4 sites, 4 coopératives, 8 apicultrices, 11 ruches,
-- 8 adhésions, 10 comptes, 528 mesures, 6 inspections, 3 récoltes, 4 alertes.
-- Les téléphones sont fictifs.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Sites : 4, dans les 3 pays, dont 2 au Sénégal (écrit avec l'accent)
-- ---------------------------------------------------------------------------
INSERT INTO site (id, nom, pays) VALUES
  ('SN-CASA', 'Casamance',    'Sénégal'),
  ('SN-KOLD', 'Kolda',        'Sénégal'),
  ('CI-YAMO', 'Yamoussoukro', 'Côte d''Ivoire'),
  ('CM-BAFO', 'Bafoussam',    'Cameroun');

-- ---------------------------------------------------------------------------
-- 2. Coopératives : 1 par site
-- ---------------------------------------------------------------------------
INSERT INTO cooperative (nom, site_id) VALUES
  ('Coopérative des apicultrices de Casamance', 'SN-CASA'),
  ('Coopérative miel de Kolda',                 'SN-KOLD'),
  ('Coopérative Abeilles du Centre',            'CI-YAMO'),
  ('Coopérative apicole des Hauts-Plateaux',    'CM-BAFO');

-- ---------------------------------------------------------------------------
-- 3. Apicultrices : 8, dont deux homonymes « Aminata Diop » (sur deux sites)
--    et une « Awa Diop ». Le téléphone, unique, sert à les distinguer.
-- ---------------------------------------------------------------------------
INSERT INTO apicultrice (nom, telephone, site_id) VALUES
  ('Aminata Diop',   '+221 77 100 00 01', 'SN-CASA'),
  ('Awa Diop',       '+221 77 100 00 02', 'SN-CASA'),
  ('Aminata Diop',   '+221 77 200 00 03', 'SN-KOLD'),   -- homonyme volontaire
  ('Mariama Ba',     '+221 77 200 00 04', 'SN-KOLD'),
  ('Adjoua Kouassi', '+225 07 300 00 05', 'CI-YAMO'),
  ('Aya Kone',       '+225 07 300 00 06', 'CI-YAMO'),
  ('Brigitte Ngono', '+237 6 400 00 07',  'CM-BAFO'),
  ('Esther Fotso',   '+237 6 400 00 08',  'CM-BAFO');

-- ---------------------------------------------------------------------------
-- 4. Ruches : 11, dont SN-CASA-099 (récolte en écart) et SN-KOLD-011 (utilisée au lab 5).
--    L'apicultrice est retrouvée par une sous-requête sur son téléphone,
--    jamais en recopiant un UUID à la main.
--    Plusieurs apicultrices ont plusieurs ruches ; Awa Diop n'en a qu'une.
-- ---------------------------------------------------------------------------
INSERT INTO ruche (code, latitude, longitude, date_installation, site_id, apicultrice_id) VALUES
  ('SN-CASA-014', 12.58330, -16.28330, '2025-11-04', 'SN-CASA',
     (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 01')),
  ('SN-CASA-099', 12.58910, -16.27650, '2026-02-12', 'SN-CASA',
     (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 01')),
  ('SN-CASA-021', 12.57480, -16.29120, '2025-12-01', 'SN-CASA',
     (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 02')),
  ('SN-KOLD-011', 12.89390, -14.94120, '2026-01-15', 'SN-KOLD',
     (SELECT id FROM apicultrice WHERE telephone = '+221 77 200 00 03')),
  ('SN-KOLD-012', 12.89810, -14.93560, '2026-01-15', 'SN-KOLD',
     (SELECT id FROM apicultrice WHERE telephone = '+221 77 200 00 03')),
  ('SN-KOLD-020', 12.88740, -14.95030, '2026-03-02', 'SN-KOLD',
     (SELECT id FROM apicultrice WHERE telephone = '+221 77 200 00 04')),
  ('CI-YAMO-001',  6.82060,  -5.27670, '2025-10-20', 'CI-YAMO',
     (SELECT id FROM apicultrice WHERE telephone = '+225 07 300 00 05')),
  ('CI-YAMO-002',  6.82540,  -5.27180, '2025-10-20', 'CI-YAMO',
     (SELECT id FROM apicultrice WHERE telephone = '+225 07 300 00 05')),
  ('CI-YAMO-010',  6.81470,  -5.28330, '2026-04-08', 'CI-YAMO',
     (SELECT id FROM apicultrice WHERE telephone = '+225 07 300 00 06')),
  ('CM-BAFO-001',  5.47750,  10.41760, '2025-09-30', 'CM-BAFO',
     (SELECT id FROM apicultrice WHERE telephone = '+237 6 400 00 07')),
  ('CM-BAFO-005',  5.48320,  10.42410, '2026-05-18', 'CM-BAFO',
     (SELECT id FROM apicultrice WHERE telephone = '+237 6 400 00 08'));

-- ---------------------------------------------------------------------------
-- 5. Adhésions : chaque apicultrice adhère à la coopérative de son site
--    (INSERT ... SELECT : la base calcule les 8 lignes)
-- ---------------------------------------------------------------------------
INSERT INTO adhesion (apicultrice_id, cooperative_id, date_adhesion)
SELECT a.id, c.id, DATE '2025-09-01'
FROM apicultrice a
JOIN cooperative c ON c.site_id = a.site_id;

-- ---------------------------------------------------------------------------
-- 6. Comptes : un par apicultrice (login « initiale.nom »), plus un
--    coordinateur et un administrateur = 10 comptes.
--    Volontairement, la formule fabrique trois fois « a.diop » : le login
--    unique sera posé au lab 4, après correction des doublons.
--    Pas de mot de passe dans le jeu d'essai : jamais de mot de passe en clair.
--    Chaque compte reçoit le haché bcrypt d'un secret aléatoire (DEFAULT de
--    schema.sql) : il s'active par une réinitialisation.
-- ---------------------------------------------------------------------------
INSERT INTO utilisateur (login, role, site_id, apicultrice_id)
SELECT lower(left(nom, 1)) || '.' || lower(split_part(nom, ' ', 2)),
       'apicultrice', site_id, id
FROM apicultrice;

INSERT INTO utilisateur (login, role, site_id) VALUES
  ('coord.casa', 'coordinateur', 'SN-CASA'),
  ('admin',      'admin',        NULL);

-- ---------------------------------------------------------------------------
-- 7. Mesures : une toutes les 30 minutes pendant 24 h, pour chaque ruche
--    generate_series(0, 47) -> 48 mesures x 11 ruches = 528 mesures
--    Valeurs aléatoires mais réalistes (couvain autour de 34-35 °C)
--    La position reçue est celle de la ruche (aucun déplacement)
-- ---------------------------------------------------------------------------
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temp_int_c, temp_ext_c,
                    humidite_pct, activite_sonore, batterie_pct, latitude, longitude)
SELECT r.id,
       TIMESTAMPTZ '2027-03-14 00:00+00' + h * INTERVAL '30 minutes',
       round((30 + random() * 15)::numeric, 2),           -- 30 à 45 kg
       round((34 + random() * 1.5)::numeric, 1),          -- 34 à 35,5 °C
       round((22 + random() * 12)::numeric, 1),           -- 22 à 34 °C
       50 + floor(random() * 30)::int,                    -- 50 à 79 %
       round(random()::numeric, 2),                       -- 0 à 1
       100 - h / 2 - floor(random() * 5)::int,            -- la batterie baisse
       r.latitude, r.longitude
FROM ruche r
CROSS JOIN generate_series(0, 47) AS h;

-- ---------------------------------------------------------------------------
-- 8. Inspections : 6, sur 5 ruches seulement
--    -> 6 ruches jamais inspectées (au moins 2 exigées, utile pour Q3 au lab 3)
--    L'inspection est réalisée par l'apicultrice propriétaire de la ruche
--    Le jeu d'essai est daté de mars 2027, comme tout le scénario du TP (mesures
--    du 14 mars 2027) : ces 6 lignes sont chargées comme une reprise de données,
--    sans le trigger « pas dans le futur » de schema.sql, remis en service juste
--    après. Toute nouvelle inspection passe par lui (test 9 de tests_schema.sql).
-- ---------------------------------------------------------------------------
ALTER TABLE inspection DISABLE TRIGGER inspection_pas_dans_le_futur;

INSERT INTO inspection (ruche_id, apicultrice_id, date_inspection, etat_colonie,
                        reine_presente, observations)
SELECT r.id, r.apicultrice_id, v.date_inspection, v.etat, v.reine, v.obs
FROM (VALUES
  ('SN-CASA-014', DATE '2027-03-01', 'bon',    true,  'Colonie forte, cadres bien remplis'),
  ('SN-CASA-014', DATE '2027-03-12', 'bon',    true,  'Début de miellée'),
  ('SN-CASA-021', DATE '2027-03-05', 'moyen',  true,  'Activité un peu faible'),
  ('SN-KOLD-011', DATE '2027-03-08', 'faible', false, 'Reine non vue, cellules royales'),
  ('CI-YAMO-001', DATE '2027-03-10', 'bon',    true,  'RAS'),
  ('CM-BAFO-001', DATE '2027-03-11', 'moyen',  true,  'Traces d''humidité dans la ruche')
) AS v(code, date_inspection, etat, reine, obs)
JOIN ruche r ON r.code = v.code;

ALTER TABLE inspection ENABLE TRIGGER inspection_pas_dans_le_futur;

-- ---------------------------------------------------------------------------
-- 9. Récoltes : 3, dont une déclarée, une validée (avec validateur et date) et une en écart
--    La validée est validée par le coordinateur du site de la ruche (SN-CASA)
-- ---------------------------------------------------------------------------
INSERT INTO recolte (ruche_id, date_recolte, quantite_kg, statut)
VALUES ((SELECT id FROM ruche WHERE code = 'CI-YAMO-002'), '2027-03-13', 9.50, 'declaree');

INSERT INTO recolte (ruche_id, date_recolte, quantite_kg, statut, validee_par, date_validation)
VALUES ((SELECT id FROM ruche WHERE code = 'SN-CASA-014'), '2027-03-10', 12.40, 'validee',
        (SELECT id FROM utilisateur WHERE login = 'coord.casa'),
        TIMESTAMPTZ '2027-03-11 09:30+00');

INSERT INTO recolte (ruche_id, date_recolte, quantite_kg, statut)
VALUES ((SELECT id FROM ruche WHERE code = 'SN-CASA-099'), '2027-03-12', 25.00, 'ecart');
                                       -- quantité incohérente avec les pesées

-- ---------------------------------------------------------------------------
-- 10. Alertes : 4, dont 2 ouvertes, sur 2 sites (SN-KOLD et CM-BAFO)
-- ---------------------------------------------------------------------------
INSERT INTO alerte (ruche_id, type, date_alerte, niveau_confiance, statut)
SELECT r.id, v.type, v.date_alerte, v.confiance, v.statut
FROM (VALUES
  ('SN-KOLD-011', 'essaimage',          TIMESTAMPTZ '2027-03-14 10:00+00', 0.82, 'ouverte'),
  ('CM-BAFO-005', 'capteur_silencieux', TIMESTAMPTZ '2027-03-14 06:30+00', 0.95, 'ouverte'),
  ('SN-CASA-021', 'stress_thermique',   TIMESTAMPTZ '2027-03-09 14:00+00', 0.61, 'fermee'),
  ('CI-YAMO-010', 'vol',                TIMESTAMPTZ '2027-03-07 02:15+00', 0.40, 'fermee')
) AS v(code, type, date_alerte, confiance, statut)
JOIN ruche r ON r.code = v.code;

COMMIT;

-- ---------------------------------------------------------------------------
-- Question du TP : relancer donnees.sql une seconde fois, sans schema.sql
-- ---------------------------------------------------------------------------
-- Obtenu :
-- BEGIN
-- psql:donnees.sql:23: ERROR:  duplicate key value violates unique constraint "site_pkey"
-- DETAIL:  Key (id)=(SN-CASA) already exists.
-- Le premier INSERT (les sites) est refusé par la CLÉ PRIMAIRE de site. Avec
-- ON_ERROR_STOP, psql s'arrête et la transaction BEGIN ... COMMIT est annulée :
-- rien n'est inséré en double (toujours 11 ruches, 528 mesures). Sans cette clé,
-- d'autres règles prendraient le relais : UNIQUE sur apicultrice.telephone et
-- ruche.code, mesure_anti_rejeu (ruche_id, horodatage), clé primaire d'adhesion.
