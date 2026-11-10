# Rendu TP Jour 1 · Base de données Queen Bee · M1 Cyber

Groupe : Praveen, Ugo, Hugo, Corentin

Ce dossier (`dossier-bdd`) contient les 4 livrables du jour, assemblés et testés ensemble (section 6). Toute la journée se rejoue d'une seule commande, et un contrôle final compare chaque résultat à l'attendu du TP.

---

## 1. Les 4 livrables

| # | Livrable | Lab | Fichiers |
|---|---|---|---|
| 1 | Modèle entité-association annoté des données sensibles et des menaces | 1 | `mcd.png` (image), `mcd.drawio` (source modifiable), `annotations.md` (questions 1 à 5, tableau STRIDE) |
| 2 | Schéma relationnel : tables, clés et relations dans PostgreSQL | 2 | `annotations.md` (section « Schéma relationnel »), `schema.sql`, `donnees.sql`, `tests_schema.sql` |
| 3 | Dépendances fonctionnelles : fermetures, clés candidates, normalisation | 4 et 5 | `plat.sql`, `dependances.md`, `contraintes.sql`, `anomalies.sql`, `migration_3nf.sql`, `normalisation.md` |
| 4 | Premier script d'interrogation sécurisé : requêtes et protection contre l'injection SQL | 3 | `requetes.sql`, `query_vuln.py` (version vulnérable, pour la démonstration), `query.py` (version corrigée, requête paramétrée) |
| – | Assemblage et test (section 6) | 6 | `rejouer_tout.ps1`, `verif_rendu.sql`, ce fichier |

## 2. Ce que contient chaque livrable, en bref

**Livrable 1 · MCD.** 9 entités (SITE, COOPÉRATIVE, APICULTRICE, RUCHE, MESURE, INSPECTION, RÉCOLTE, ALERTE, UTILISATEUR), 13 associations, dont ADHÈRE (n,n, porte `date_adhesion`), VALIDE (entre UTILISATEUR et RÉCOLTE) et EST AFFECTÉ (le site d'un compte, d'où `utilisateur.site_id`). Les attributs sensibles sont en rouge (téléphone, positions GPS, login, hash du mot de passe, quantité récoltée, photo). Le tableau STRIDE couvre les 9 entités, les 4 rôles et les 6 lettres, avec les trois cas imposés : mesure rejouée, récolte validée sans validateur connu, effacement de l'historique.

**Livrable 2 · Schéma.** 10 tables, 14 clés étrangères nommées `table_colonne_fk`. UUID pour tout ce qu'une application expose, code lisible pour le site, `bigint` pour la mesure. Règles de sécurité : `mesure_anti_rejeu UNIQUE (ruche_id, horodatage)`, `recolte_quantite_positive`, `recolte_validation_tracee` (pas de récolte « validée » sans validateur ni date), `alerte_confiance_bornee`, plages physiques sur les mesures, cohérence rôle / apicultrice / site sur les comptes. `tests_schema.sql` montre les 8 refus attendus (tests 1, 2, 3, 6, 7, 8, et deux au test 9). Après le retour de la prof (section 7) : haché bcrypt obligatoire, ruche forcément sur le site de son apicultrice, pas d'inspection dans le futur, un index par clé étrangère.

**Livrable 3 · DF et normalisation.** 4 DF retenues sur `extrait_plat`, une fausse (`apicultrice → telephone`, les deux « Aminata Diop »), clé candidate `{ruche_code, horodatage}`. Logins rendus uniques (`utilisateur_login_unique`) et insensibles à la casse (`utilisateur_login_ci`). Les trois anomalies sont provoquées, puis `extrait_plat` (en 1NF seulement) est découpée en 4 tables BCNF dans le schéma `norm` (avec l'hypothèse du lab 4 ; `norm.ruche` ne l'est plus depuis la correction 4, voir `normalisation.md`). La migration est refusée sur les données corrompues, puis acceptée après nettoyage. Preuve sans perte : 0 ligne de différence.

**Livrable 4 · Requêtes et injection.** Q1 à Q5 avec leur algèbre ; la vue `v_ruche_coordinateur` n'expose ni nom ni téléphone. `query_vuln.py` concatène la saisie et se fait injecter (`' OR '1'='1` → toutes les ruches ; `' UNION SELECT nom, telephone FROM apicultrice --` → les téléphones). `query.py` utilise `%s` : 1, 0 et 0 ligne. Aucun mot de passe dans le code : il est lu dans les variables d'environnement.

## 3. Rejouer et tester toute la journée

Depuis `dossier-bdd`, dans PowerShell, avec la base `queenbee` déjà créée (étape 0.4). Définissez d'abord, dans le terminal, les trois variables de connexion de l'étape 3.2 du TP (utilisateur, mot de passe, hôte). Le mot de passe n'est écrit dans aucun fichier. Puis :

```powershell
powershell -ExecutionPolicy Bypass -File .\rejouer_tout.ps1
```

Attention : `schema.sql` supprime et recrée les tables, la base repart donc de zéro.

Le script lance les fichiers dans l'ordre des labs. Il vérifie que les refus voulus se produisent et s'arrête à la première erreur qui n'était pas prévue :

| # | Fichier | Lab | Ce qui doit se passer |
|---|---|---|---|
| 1 | `schema.sql` | 2 | 10 `CREATE TABLE`, le trigger d'inspection et 11 `CREATE INDEX` |
| 2 | `donnees.sql` | 2 | les `INSERT`, puis `COMMIT` |
| 3 | `tests_schema.sql` | 2 | une `ERROR` pour les tests 1, 2, 3, 6, 7 et 8, deux pour le test 9, chacune nommant sa règle |
| 4 | `requetes.sql` | 3 | les cinq résultats, sans `ERROR` |
| 5 | `plat.sql` | 4 | `extrait_plat`, 528 lignes |
| 6 | `contraintes.sql` | 4 | 0 ligne pour chaque DF, « Aminata Diop » ×2 ; `ERROR` aux commandes 2 et 6 (voulues) |
| 7 | `plat.sql` | 5 | extrait propre |
| 8 | `anomalies.sql`, partie 5.1 | 5 | 3 pays puis 4 ; téléphone disparu ; site sans ruche refusé |
| 9 | `migration_3nf.sql` | 5 | **refus** : `duplicate key ... "site_pkey"` (SN-KOLD) |
| 10 | `anomalies.sql`, partie 5.2 | 5 | conflits retrouvés et corrigés |
| 11 | `migration_3nf.sql` | 5 | `INSERT 0 4 / 8 / 11 / 528`, `COMMIT` |
| 12 | `anomalies.sql`, partie 5.3 | 5 | 0 ligne de différence ; second pays refusé ; site sans ruche accepté ; 3 pays |
| 13 | `query_vuln.py` puis `query.py` (si Python et psycopg sont installés) | 3 | `query_vuln.py` : 1, 11, 8 lignes (l'injection passe) ; `query.py` : 1, 0, 0 (elle est bloquée) |
| 14 | `verif_rendu.sql` | 6 | 33 contrôles, tous OK |

Le script coupe `anomalies.sql` aux deux lignes `-- Ici, dans le terminal` : la migration doit passer entre les morceaux, comme pendant le TP.

Sous Windows, le script force `PGCLIENTENCODING=UTF8`. Sans cela, psql lit les fichiers en WIN1252 et « Sénégal » ne passe plus le `CHECK` de la table `site`.

## 4. Résultat du contrôle final (`verif_rendu.sql`)

Obtenu en rejouant toute la chaîne sur une base vierge (PostgreSQL 18) :

```
 #  |  livrable  |                    controle                         | attendu | obtenu | resultat
----+------------+-----------------------------------------------------+---------+--------+----------
  1 | 2 schéma   | tables du schéma                                    | 10      | 10     | OK
  2 | 2 schéma   | clés étrangères nommées _fk                         | 14      | 14     | OK
  3 | 2 schéma   | règles de sécurité (anti-rejeu, validation, ...)    | 4       | 4      | OK
  4 | 2 schéma   | sites                                               | 4       | 4      | OK
  5 | 2 schéma   | apicultrices                                        | 8       | 8      | OK
  6 | 2 schéma   | ruches                                              | 11      | 11     | OK
  7 | 2 schéma   | mesures (11 x 48)                                   | 528     | 528    | OK
  8 | 2 schéma   | adhésions                                           | 8       | 8      | OK
  9 | 2 schéma   | comptes                                             | 10      | 10     | OK
 10 | 2 schéma   | inspections                                         | 6       | 6      | OK
 11 | 2 schéma   | récoltes                                            | 3       | 3      | OK
 12 | 2 schéma   | alertes                                             | 4       | 4      | OK
 13 | 4 requêtes | Q2 : une ligne par apicultrice (homonymes séparées) | 8       | 8      | OK
 14 | 4 requêtes | Q3 : ruches jamais inspectées (au moins 2)          | oui     | oui    | OK
 15 | 4 requêtes | Q4 : sites avec une alerte ouverte                  | 2       | 2      | OK
 16 | 4 requêtes | Q5 : v_ruche_coordinateur, une ligne par ruche      | 11      | 11     | OK
 17 | 4 requêtes | Q5 : la vue n'expose ni nom ni téléphone            | 0       | 0      | OK
 18 | 3 DF       | extrait_plat : une ligne par mesure                 | 528     | 528    | OK
 19 | 3 DF       | contrainte utilisateur_login_unique posée           | 1       | 1      | OK
 20 | 3 DF       | index utilisateur_login_ci posé                     | 1       | 1      | OK
 21 | 3 DF       | logins en double (casse ignorée)                    | 0       | 0      | OK
 22 | 3 DF       | norm.site                                           | 4       | 4      | OK
 23 | 3 DF       | norm.apicultrice                                    | 8       | 8      | OK
 24 | 3 DF       | norm.ruche                                          | 11      | 11     | OK
 25 | 3 DF       | norm.mesure                                         | 528     | 528    | OK
 26 | 3 DF       | décomposition sans perte (lignes de différence)     | 0       | 0      | OK
 27 | 3 DF       | enquête par pays sur les tables norm                | 3       | 3      | OK
 28 | correction | 2 : mot_de_passe_hash NOT NULL                      | oui     | oui    | OK
 29 | correction | 2 : comptes au haché bcrypt                         | 10      | 10     | OK
 30 | correction | 4 : ruche_apicultrice_fk composée avec site_id      | oui     | oui    | OK
 31 | correction | 4 : ruches hors du site de leur apicultrice         | 0       | 0      | OK
 32 | correction | 5 : inspection, CHECK 2020 + trigger futur actif    | 2       | 2      | OK
 33 | correction | 6 : clés étrangères couvertes par un index          | 14      | 14     | OK

 0 contrôle(s) en échec sur 33
```

Programmes Python, rejoués par le même script (Python 3.13, psycopg 3.3) :

```
  SN-CASA-014                                        query_vuln.py :  1 ligne(s) | query.py : 1 ligne(s) [OK]
  ' OR '1'='1                                        query_vuln.py : 11 ligne(s) | query.py : 0 ligne(s) [OK]
  ' UNION SELECT nom, telephone FROM apicultrice --  query_vuln.py :  8 ligne(s) | query.py : 0 ligne(s) [OK]
```

Vérifiés à part, sur une base de test, parce qu'ils détruisent des données ou sortent du jour 1 :
- **Requêtes empilées.** `'; COMMIT; DROP TABLE alerte CASCADE; COMMIT; SELECT 'x','y' --` supprime vraiment la table `alerte` avec `query_vuln.py`. `query.py` renvoie 0 ligne.
- **Argument « requête préparée » de `query.py`.** Avec `%s`, un texte de requête qui contient deux instructions est refusé : `SyntaxError - cannot insert multiple commands into a prepared statement`.
- **SQL proposé pour le jour 2** (limites de `tests_schema.sql`), testé puis annulé par `ROLLBACK` :
  - limite 1 : la validation par l'admin, ou par le coordinateur d'un autre site, est refusée par `recolte_coord_site_fk` ; celle de `coord.casa` sur une ruche de SN-CASA est acceptée ;
  - limite 2 : un compte apicultrice déplacé sur un autre site est refusé ;
  - limite 3 : `recolte_statut_coherent` est refusée tant que la récolte « ecart » n'a pas de validateur ; une validation antérieure à la récolte est refusée ;
  - limite 4 : une trame datée `infinity` est refusée, une trame vide aussi ;
  - limite 7 : `A.Diop` et un login contenant un « а » cyrillique sont refusés.

## 5. Sécurité du rendu

- Aucun mot de passe dans les fichiers : la recherche `git grep -i` du lab 3 (le mot « mot de passe » en anglais) ne trouve rien dans les fichiers du jour 1 (au jour 2, seule sort la ligne du rapport de revue qui recopie la commande). Les mots de passe des comptes ne sont pas dans le jeu d'essai : chaque compte reçoit le haché bcrypt d'un secret aléatoire que personne ne connaît (section 7), et celui de PostgreSQL vient d'une variable d'environnement du terminal.
- Les téléphones du jeu d'essai sont fictifs.
- `query_vuln.py` est volontairement vulnérable : c'est la démonstration du lab 3, il ne doit jamais servir ailleurs.

## 6. Limites connues, pour le jour 2

Elles sont détaillées à la fin de `tests_schema.sql`. Les principales :

1. La base ne vérifie pas que `validee_par` est un **coordinateur du site** de la ruche (il faut un trigger ou des droits par rôle).
2. Le site d'un compte apicultrice peut différer de celui de son apicultrice. Correction prévue : une clé étrangère composite `(apicultrice_id, site_id)`.
3. Une récolte validée reste modifiable sans trace (il faut figer les récoltes validées et tenir une table d'audit).
4. L'anti-rejeu ne refuse que la trame **identique**. Un vrai anti-rejeu demande un compteur, une signature HMAC du capteur et un contrôle de l'horodatage.
5. Le programme se connecte en `postgres` (superutilisateur). Il faudrait un rôle limité, par exemple `GRANT SELECT (code, site_id) ON ruche`, et de la Row Level Security par apicultrice ou par site.

## 7. Corrections suite au retour de la prof

| # | Remarque | Ce qui a changé, et où | Comment le vérifier |
|---|---|---|---|
| 1 | `mcd.drawio` est vide (0 octet) | Il ne l'était pas : 34 787 octets de XML valide (121 `mxCell`), mais sur **une seule ligne** sans retour final, d'où « 0 » avec `wc -l`. Il est réindenté sur 419 lignes ; le XML est le même (mêmes éléments, attributs et valeurs, comparés après lecture des deux fichiers). | `wc -l mcd.drawio` ; le fichier s'ouvre dans draw.io |
| 2 | `mot_de_passe_hash` peut être NULL | `schema.sql` : colonne `NOT NULL`, valeur par défaut `crypt(gen_random_uuid()::text, gen_salt('bf'))` (extension pgcrypto) : chaque compte reçoit le haché bcrypt d'un secret aléatoire que personne ne connaît, et s'active par une réinitialisation. Le CHECK `utilisateur_hache_bcrypt` impose le format bcrypt. Aucun secret en clair nulle part. | contrôles 28 et 29 de `verif_rendu.sql` |
| 3 | Une apicultrice peut valider une récolte | Traité au jour 2 (lab 8), comme prévu : `jour2/2_roles_privileges/roles.sql` retire l'`UPDATE` sur `recolte` et passe la validation par la fonction `valider_recolte` (`SECURITY DEFINER`), réservée au coordinateur du site de la ruche. Le schéma du jour 1 ne change pas. | tests 6 et 7 de `jour2/2_roles_privileges/tests_contournement.sql` (refusés) |
| 4 | `ruche.site_id` peut différer du site de l'apicultrice | `schema.sql` : `apicultrice_id_site_uq UNIQUE (id, site_id)`, et `ruche_apicultrice_fk` devient une clé étrangère **composée** `(apicultrice_id, site_id)` → `apicultrice (id, site_id)`, sous le même nom et avec le même `ON DELETE` (toujours 14 clés étrangères). La transhumance deviendra une entité à part (`annotations.md`, question 4). Effet sur les DF du lab 4 : notes dans `dependances.md` et `normalisation.md`. | test 7 de `tests_schema.sql` (refus) ; contrôles 30 et 31 |
| 5 | Une inspection datée de 2099 est acceptée | `schema.sql` : CHECK `inspection_date_plausible` (pas avant le 1er janvier 2020) et trigger `inspection_pas_dans_le_futur` (`BEFORE INSERT OR UPDATE OF date_inspection`), qui refuse une date postérieure à `current_date`. Pas de CHECK avec `now()` : PostgreSQL suppose qu'un CHECK donne toujours le même résultat (risque à la restauration). Le jeu d'essai est daté de mars 2027, comme tout le scénario du TP : `donnees.sql` charge ses 6 inspections trigger désactivé (reprise de données), puis le remet en service. | test 9 de `tests_schema.sql` (2099 et 2019 refusées, aujourd'hui acceptée) ; contrôle 32 |
| 6 | Aucune clé étrangère n'est indexée | `schema.sql`, section 11 : 11 index. Les 3 autres clés sont déjà en tête d'une clé primaire ou d'un UNIQUE (`adhesion`, `utilisateur.apicultrice_id`, `mesure (ruche_id, horodatage)`), c'est indiqué en commentaire. Le jour 2 suit la même règle (3 index dans `formation.sql` et `jeton.sql`). Cela vaut pour le schéma `public` ; le schéma d'exercice `norm` du lab 5 (2 clés sans index) n'est pas concerné. | contrôle 33 (14 clés sur 14) |
| 7 | Ajoutez `*.dump` au `.gitignore` | Ligne `*.dump` dans le `.gitignore` de la racine (le `jour2/.gitignore` l'avait déjà). | `git check-ignore -v essai.dump` |

Le jour 1 se rejoue toujours d'une seule commande ; `verif_rendu.sql` compte désormais 33 contrôles (27 + 6 pour ces corrections), tous OK (section 4).
