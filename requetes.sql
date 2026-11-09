-- requetes.sql : cinq questions à la base Queen Bee (TP Jour 1, Lab 3, étape 3.1)
-- Groupe : Praveen, Ugo, Hugo, Corentin
-- Lancement : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f requetes.sql
-- Le fichier peut être relancé autant de fois qu'on veut (CREATE OR REPLACE VIEW).

-- ---------------------------------------------------------------------------
-- Q1. Les ruches du site SN-CASA, avec leur position
-- Algèbre : π code, latitude, longitude ( σ site_id = 'SN-CASA' ( ruche ) )
-- ---------------------------------------------------------------------------
SELECT code, latitude, longitude
FROM ruche
WHERE site_id = 'SN-CASA'
ORDER BY code;
-- Résultat : 3 lignes

-- ---------------------------------------------------------------------------
-- Q2. Chaque apicultrice et son nombre de ruches
-- Algèbre : γ a.id, a.nom, a.site_id ; count(r.id) ( apicultrice a ⟕ a.id = r.apicultrice_id ruche r )
--           (⟕ = jointure externe gauche : on garde aussi les apicultrices sans ruche ;
--            γ = regroupement, on groupe par id et non par nom)
-- GROUP BY sur l'id : les deux « Aminata Diop » restent sur deux lignes.
-- ---------------------------------------------------------------------------
SELECT a.nom, a.site_id, count(r.id) AS nb_ruches
FROM apicultrice a
LEFT JOIN ruche r ON r.apicultrice_id = a.id
GROUP BY a.id, a.nom, a.site_id
ORDER BY nb_ruches DESC, a.nom, a.site_id;
-- Résultat : 8 lignes

-- ---------------------------------------------------------------------------
-- Q3. Les ruches jamais inspectées
-- Algèbre : π code ( ruche ⋈ ( π id ( ruche ) − ρ ruche_id→id ( π ruche_id ( inspection ) ) ) )
--           (différence : tous les ids de ruche moins ceux qui ont une inspection)
-- ---------------------------------------------------------------------------
SELECT code
FROM ruche
WHERE id IN (SELECT id FROM ruche
             EXCEPT
             SELECT ruche_id FROM inspection)
ORDER BY code;
-- Résultat : 6 lignes

-- ---------------------------------------------------------------------------
-- Q4. Les sites qui ont au moins une alerte ouverte (chaque site une seule fois)
-- Algèbre : π site_id ( σ statut = 'ouverte' ( alerte ⋈ alerte.ruche_id = ruche.id ruche ) )
--           (π élimine les doublons en algèbre pure ; en SQL il faut DISTINCT)
-- ---------------------------------------------------------------------------
SELECT DISTINCT r.site_id
FROM alerte al
JOIN ruche r ON r.id = al.ruche_id
WHERE al.statut = 'ouverte'
ORDER BY r.site_id;
-- Résultat : 2 lignes

-- ---------------------------------------------------------------------------
-- Q5. Une vue qui n'expose que le nécessaire : v_ruche_coordinateur
-- Algèbre : π code, site_id, derniere_pesee_kg, derniere_pesee_le
--           ( ρ poids_kg→derniere_pesee_kg, horodatage→derniere_pesee_le ( ruche ⟕ dernière mesure de la ruche ) )
-- Aucun nom, aucun téléphone : la table apicultrice n'est pas touchée.
-- « Dernière pesée » = poids de la mesure la plus récente de la ruche.
-- LEFT JOIN LATERAL : une ligne par ruche, même si une ruche n'avait aucune mesure.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_ruche_coordinateur AS
SELECT r.code, r.site_id, m.poids_kg AS derniere_pesee_kg, m.horodatage AS derniere_pesee_le
FROM ruche r
LEFT JOIN LATERAL (SELECT poids_kg, horodatage FROM mesure
                   WHERE ruche_id = r.id AND poids_kg IS NOT NULL
                   ORDER BY horodatage DESC LIMIT 1) m ON true;

SELECT * FROM v_ruche_coordinateur ORDER BY code;
-- Résultat : 11 lignes
-- (les poids sont aléatoires : ils changent d'un jeu d'essai à l'autre)

-- ---------------------------------------------------------------------------
-- Pourquoi une application ne doit jamais faire SELECT * sur apicultrice
-- ---------------------------------------------------------------------------
-- 1. Minimisation (RGPD) : on ne doit lire que les données nécessaires à la
--    finalité. SELECT * ramène aussi le téléphone, une donnée personnelle, alors
--    que l'écran n'a souvent besoin que du nom ou de l'id.
-- 2. Exposition inutile : tout ce qui sort de la base peut finir dans un
--    journal, une réponse d'API, un message d'erreur, ou être volé (injection).
--    Moins on lit de colonnes, moins on peut en divulguer.
-- 3. Colonnes ajoutées plus tard : si on ajoute une colonne sensible (adresse,
--    date de naissance, pièce d'identité...), SELECT * l'expose automatiquement,
--    sans que personne ne l'ait décidé ni relu.
-- 4. Projection = moindre privilège au niveau des colonnes : on liste
--    explicitement les colonnes autorisées (ou on passe par une vue comme
--    v_ruche_coordinateur), et le code reste stable si le schéma évolue.
-- 5. Robustesse et performance : l'ordre et le nombre de colonnes ne changent
--    pas sous les pieds du programme, et on ne transporte pas des données inutiles.

-- ---------------------------------------------------------------------------
-- Testez-vous · Lab 3 : réponses courtes
-- ---------------------------------------------------------------------------
-- 1. JOIN (jointure interne) ne garde que les apicultrices qui ont au moins une
--    ruche : celles sans ruche disparaissent, au lieu d'afficher 0. LEFT JOIN
--    garde toutes les apicultrices, avec NULL côté ruche quand il n'y en a pas ;
--    count(r.id) ignore les NULL et donne bien 0. Pour compter, on utilise donc
--    LEFT JOIN, avec GROUP BY sur l'id.
-- 2. L'apostrophe ferme la chaîne de texte ouverte par le programme : ce qui suit
--    n'est plus lu comme une valeur mais comme du SQL. Les deux tirets (--) ouvrent
--    un commentaire : tout le reste de la requête d'origine (l'apostrophe finale)
--    est ignoré, ce qui évite une erreur de syntaxe. UNION SELECT, lui, ajoute une
--    seconde requête dont le résultat s'affiche avec le premier.
-- 3. Parce qu'un filtre de caractères est une liste noire fragile :
--    - un champ numérique s'injecte sans apostrophe (id = 1 OR 1=1) ;
--    - injection de second ordre : une valeur stockée puis réutilisée plus tard
--      dans une requête concaténée ;
--    - une couche qui normalise l'Unicode (’ -> ') ou un mauvais échappement
--      (antislash) peut réintroduire l'apostrophe ;
--    - on casse des noms légitimes (« N'Diaye », « Côte d'Ivoire »).
--    Dans le cas précis de query_vuln.py, retirer les apostrophes empêche de
--    sortir de la chaîne : le filtre est fragile, pas inopérant. La seule
--    protection fiable est la requête paramétrée : la valeur ne passe jamais
--    par le texte SQL.
