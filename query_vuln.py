# query_vuln.py : programme VULNÉRABLE à l'injection SQL (TP Jour 1, Lab 3, étape 3.2)
# Groupe : Praveen, Ugo, Hugo, Corentin
# Lancement : python query_vuln.py
# Connexion : psycopg lit PGUSER, PGHOST... et le mot de passe dans les variables
# d'environnement du terminal : rien de secret n'est écrit dans le code.
# Le nom de la base est lu dans PGDATABASE, avec "queenbee" par défaut
# (cela permet de tester sur une autre base sans modifier le fichier).
import os
import psycopg

conn = psycopg.connect(dbname=os.environ.get("PGDATABASE", "queenbee"))
code = input("Code ruche : ")

# DANGER : la saisie est collée dans le texte de la requête (concaténation)
sql = "SELECT code, site_id FROM ruche WHERE code = '" + code + "'"
print("Requête envoyée :", sql)
for row in conn.execute(sql):
    print(row)
