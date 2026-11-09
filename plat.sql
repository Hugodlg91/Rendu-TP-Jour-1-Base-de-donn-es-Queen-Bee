-- plat.sql : table « à plat » pour voir les dépendances (TP Jour 1, Lab 4, étape 4.1)
-- Groupe : Praveen, Ugo, Hugo, Corentin
-- Comme un export de tableur : chaque mesure est recopiée avec tout son contexte.
-- Lancement : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f plat.sql
-- Résultat attendu : 528 lignes (autant que de mesures)

DROP TABLE IF EXISTS extrait_plat;

CREATE TABLE extrait_plat AS
SELECT r.code        AS ruche_code,
       s.id          AS site_id,
       s.nom         AS site_nom,
       s.pays,
       a.nom         AS apicultrice,
       a.telephone,
       c.nom         AS cooperative,
       m.horodatage,
       m.poids_kg,
       m.temp_int_c
FROM mesure m
JOIN ruche r       ON r.id = m.ruche_id
JOIN site s        ON s.id = r.site_id
JOIN apicultrice a ON a.id = r.apicultrice_id
JOIN adhesion ad   ON ad.apicultrice_id = a.id
JOIN cooperative c ON c.id = ad.cooperative_id;
