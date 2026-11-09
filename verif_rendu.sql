-- verif_rendu.sql : contrôle final des 4 livrables (TP Jour 1, section 6)
-- Groupe : Praveen, Ugo, Hugo, Corentin
-- À lancer en DERNIER, une fois toute la chaîne rejouée (voir rejouer_tout.ps1) :
--   psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f verif_rendu.sql
-- Chaque ligne compare l'attendu du TP à ce que contient la base.
-- Résultat attendu : toutes les lignes à OK, puis « 0 contrôle(s) en échec ».

-- Table temporaire : elle disparaît à la fin de la session psql
CREATE TEMP TABLE controle (num serial, livrable text, controle text, attendu text, obtenu text);

INSERT INTO controle (livrable, controle, attendu, obtenu) VALUES
-- Livrable 2 · schéma relationnel (lab 2)
('2 schéma', 'tables du schéma', '10',
  (SELECT count(*) FROM information_schema.tables
   WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
     AND table_name IN ('site','cooperative','apicultrice','ruche','adhesion',
                        'utilisateur','mesure','inspection','recolte','alerte'))::text),
('2 schéma', 'clés étrangères nommées _fk', '14',
  (SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
   WHERE n.nspname = 'public' AND c.contype = 'f' AND c.conname LIKE '%\_fk')::text),
('2 schéma', 'règles de sécurité (anti-rejeu, validation tracée, confiance bornée, quantité > 0)', '4',
  (SELECT count(*) FROM pg_constraint
   WHERE conname IN ('mesure_anti_rejeu', 'recolte_validation_tracee',
                     'alerte_confiance_bornee', 'recolte_quantite_positive'))::text),
('2 schéma', 'sites',        '4',   (SELECT count(*) FROM site)::text),
('2 schéma', 'apicultrices', '8',   (SELECT count(*) FROM apicultrice)::text),
('2 schéma', 'ruches',       '11',  (SELECT count(*) FROM ruche)::text),
('2 schéma', 'mesures (11 x 48)', '528', (SELECT count(*) FROM mesure)::text),
('2 schéma', 'adhésions',    '8',   (SELECT count(*) FROM adhesion)::text),
('2 schéma', 'comptes',      '10',  (SELECT count(*) FROM utilisateur)::text),
('2 schéma', 'inspections',  '6',   (SELECT count(*) FROM inspection)::text),
('2 schéma', 'récoltes',     '3',   (SELECT count(*) FROM recolte)::text),
('2 schéma', 'alertes',      '4',   (SELECT count(*) FROM alerte)::text),
-- Livrable 4 · requêtes (lab 3)
('4 requêtes', 'Q2 : une ligne par apicultrice (homonymes séparées)', '8',
  (SELECT count(*) FROM (SELECT a.id FROM apicultrice a LEFT JOIN ruche r ON r.apicultrice_id = a.id
                         GROUP BY a.id) t)::text),
('4 requêtes', 'Q3 : ruches jamais inspectées (au moins 2)', 'oui',
  CASE WHEN (SELECT count(*) FROM (SELECT id FROM ruche EXCEPT SELECT ruche_id FROM inspection) t) >= 2
       THEN 'oui' ELSE 'non' END),
('4 requêtes', 'Q4 : sites avec une alerte ouverte', '2',
  (SELECT count(DISTINCT r.site_id) FROM alerte al JOIN ruche r ON r.id = al.ruche_id
   WHERE al.statut = 'ouverte')::text),
('4 requêtes', 'Q5 : v_ruche_coordinateur, une ligne par ruche', '11',
  (SELECT count(*) FROM v_ruche_coordinateur)::text),
('4 requêtes', 'Q5 : la vue n''expose ni nom ni téléphone', '0',
  (SELECT count(*) FROM information_schema.columns
   WHERE table_name = 'v_ruche_coordinateur' AND column_name IN ('nom', 'telephone'))::text),
-- Livrable 3 · dépendances fonctionnelles et normalisation (labs 4 et 5)
('3 DF', 'extrait_plat : une ligne par mesure', '528', (SELECT count(*) FROM extrait_plat)::text),
('3 DF', 'contrainte utilisateur_login_unique posée', '1',
  (SELECT count(*) FROM pg_constraint WHERE conname = 'utilisateur_login_unique')::text),
('3 DF', 'index utilisateur_login_ci (insensible à la casse) posé', '1',
  (SELECT count(*) FROM pg_indexes WHERE indexname = 'utilisateur_login_ci')::text),
('3 DF', 'logins en double (casse ignorée)', '0',
  (SELECT count(*) FROM (SELECT lower(login) FROM utilisateur GROUP BY 1 HAVING count(*) > 1) t)::text),
('3 DF', 'norm.site',        '4',   (SELECT count(*) FROM norm.site)::text),
('3 DF', 'norm.apicultrice', '8',   (SELECT count(*) FROM norm.apicultrice)::text),
('3 DF', 'norm.ruche',       '11',  (SELECT count(*) FROM norm.ruche)::text),
('3 DF', 'norm.mesure',      '528', (SELECT count(*) FROM norm.mesure)::text),
('3 DF', 'décomposition sans perte (lignes de différence)', '0',
  (SELECT count(*) FROM ((SELECT * FROM extrait_plat EXCEPT SELECT * FROM norm.reconstruit)
                         UNION ALL
                         (SELECT * FROM norm.reconstruit EXCEPT SELECT * FROM extrait_plat)) t)::text),
('3 DF', 'enquête par pays sur les tables norm', '3',
  (SELECT count(DISTINCT s.pays) FROM norm.mesure m
   JOIN norm.ruche r USING (ruche_code) JOIN norm.site s ON s.site_id = r.site_id)::text);

SELECT num AS "#", livrable, controle, attendu, obtenu,
       CASE WHEN attendu = obtenu THEN 'OK' ELSE 'KO' END AS resultat
FROM controle ORDER BY num;

SELECT count(*) FILTER (WHERE attendu <> obtenu) || ' contrôle(s) en échec sur '
       || count(*) AS bilan
FROM controle;

-- Si un contrôle est KO, on lève une erreur : avec ON_ERROR_STOP, psql
-- s'arrête avec un code de sortie non nul (utilisé par rejouer_tout.ps1).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM controle WHERE attendu <> obtenu) THEN
    RAISE EXCEPTION 'verif_rendu : au moins un contrôle est KO (voir le tableau ci-dessus)';
  END IF;
END $$;
