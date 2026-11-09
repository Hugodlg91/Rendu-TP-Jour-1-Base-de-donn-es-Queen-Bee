# query.py : version CORRIGÉE de query_vuln.py (TP Jour 1, Lab 3, étape 3.2)
# Groupe : Praveen, Ugo, Hugo, Corentin
# Lancement : python query.py
#
# Résultats des tests (mêmes saisies dans les deux programmes) :
# | Saisie                                     | query_vuln.py                          | query.py |
# | code normal (SN-CASA-014)                  | 1 ligne                                | 1 ligne  |
# | ' OR '1'='1                                | 11 lignes (toutes les ruches)          | 0 ligne  |
# | ' UNION SELECT nom, telephone FROM apicultrice -- | 8 lignes (noms + téléphones)    | 0 ligne  |
# | '; COMMIT; DROP TABLE alerte CASCADE; COMMIT; SELECT 'x','y' -- | table alerte SUPPRIMÉE (requêtes empilées) | 0 ligne  |
# Après le test DROP sur query_vuln.py, recharger la base (schema.sql puis donnees.sql)
# avant de continuer : requetes.sql et la suite utilisent la table alerte.
# Pourquoi query.py résiste : la requête (avec le marqueur %s) et la valeur saisie
# partent séparément vers PostgreSQL. La saisie est toujours traitée comme une
# simple valeur (un texte à comparer), jamais comme du SQL : les apostrophes et
# les deux tirets n'ont aucun pouvoir, la base cherche une ruche dont le code est
# littéralement « ' OR '1'='1 », et n'en trouve aucune.
# Argument technique en plus : avec des paramètres, psycopg 3 envoie une requête
# préparée, qui n'accepte qu'une seule instruction. Un texte de requête contenant
# deux instructions est refusé (vérifié : SyntaxError « cannot insert multiple
# commands into a prepared statement »), donc des requêtes empilées sont
# impossibles, et la saisie reste de toute façon une valeur même si elle
# contient un « ; ».
#
# Défense en profondeur : ce programme se connecte en postgres (superutilisateur),
# ce qui donne à une injection tous les droits (lire, modifier, supprimer). Une
# vraie application utiliserait un rôle limité, par exemple :
#   CREATE ROLE app_lecture_ruche LOGIN;
#   GRANT SELECT (code, site_id) ON ruche TO app_lecture_ruche;
# Même une injection oubliée ne pourrait alors ni lire apicultrice, ni rien modifier.
# Ce GRANT n'empêche pas l'IDOR (on peut toujours lire n'importe quelle ruche par
# son code) : c'est le contrôle d'accès par site / apicultrice qui le traite
# (voir tests_schema.sql).
#
# Connexion : PGUSER, PGHOST... et le mot de passe viennent des variables
# d'environnement, jamais du code. Le nom de la base est lu dans PGDATABASE,
# avec "queenbee" par défaut (pratique pour tester sur une autre base).
import os
import psycopg

with psycopg.connect(dbname=os.environ.get("PGDATABASE", "queenbee")) as conn:
    code = input("Code ruche : ")
    rows = conn.execute("SELECT code, site_id FROM ruche WHERE code = %s", (code,)).fetchall()
print(len(rows), "ligne(s)")
for row in rows:
    print(row)
