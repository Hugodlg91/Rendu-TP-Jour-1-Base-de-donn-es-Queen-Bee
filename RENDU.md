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

**Livrable 2 · Schéma.** 10 tables, 14 clés étrangères nommées `table_colonne_fk`. UUID pour tout ce qu'une application expose, code lisible pour le site, `bigint` pour la mesure. Règles de sécurité : `mesure_anti_rejeu UNIQUE (ruche_id, horodatage)`, `recolte_quantite_positive`, `recolte_validation_tracee` (pas de récolte « validée » sans validateur ni date), `alerte_confiance_bornee`, plages physiques sur les mesures, cohérence rôle / apicultrice / site sur les comptes. `tests_schema.sql` montre les 5 refus attendus (tests 1, 2, 3, 6, 8).

**Livrable 3 · DF et normalisation.** 4 DF retenues sur `extrait_plat`, une fausse (`apicultrice → telephone`, les deux « Aminata Diop »), clé candidate `{ruche_code, horodatage}`. Logins rendus uniques (`utilisateur_login_unique`) et insensibles à la casse (`utilisateur_login_ci`). Les trois anomalies sont provoquées, puis `extrait_plat` (en 1NF seulement) est découpée en 4 tables BCNF dans le schéma `norm`. La migration est refusée sur les données corrompues, puis acceptée après nettoyage. Preuve sans perte : 0 ligne de différence.

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
| 1 | `schema.sql` | 2 | 10 `CREATE TABLE` |
| 2 | `donnees.sql` | 2 | les `INSERT`, puis `COMMIT` |
| 3 | `tests_schema.sql` | 2 | une `ERROR` pour les tests 1, 2, 3, 6 et 8, chacune nommant sa règle |
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
| 14 | `verif_rendu.sql` | 6 | 27 contrôles, tous OK |

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

 0 contrôle(s) en échec sur 27
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

- Aucun mot de passe dans les fichiers : la recherche `git grep -i` du lab 3 (le mot « mot de passe » en anglais) ne trouve rien. Les mots de passe des comptes ne sont pas dans le jeu d'essai (colonne `mot_de_passe_hash` vide), et celui de PostgreSQL vient d'une variable d'environnement du terminal.
- Les téléphones du jeu d'essai sont fictifs.
- `query_vuln.py` est volontairement vulnérable : c'est la démonstration du lab 3, il ne doit jamais servir ailleurs.

## 6. Limites connues, pour le jour 2

Elles sont détaillées à la fin de `tests_schema.sql`. Les principales :

1. La base ne vérifie pas que `validee_par` est un **coordinateur du site** de la ruche (il faut un trigger ou des droits par rôle).
2. Le site d'un compte apicultrice peut différer de celui de son apicultrice. Correction prévue : une clé étrangère composite `(apicultrice_id, site_id)`.
3. Une récolte validée reste modifiable sans trace (il faut figer les récoltes validées et tenir une table d'audit).
4. L'anti-rejeu ne refuse que la trame **identique**. Un vrai anti-rejeu demande un compteur, une signature HMAC du capteur et un contrôle de l'horodatage.
5. Le programme se connecte en `postgres` (superutilisateur). Il faudrait un rôle limité, par exemple `GRANT SELECT (code, site_id) ON ruche`, et de la Row Level Security par apicultrice ou par site.
