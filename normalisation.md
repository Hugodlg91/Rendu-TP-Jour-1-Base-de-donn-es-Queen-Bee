# normalisation.md : TP Jour 1, Lab 5 (formes normales)

Groupe : Praveen, Ugo, Hugo, Corentin

Table étudiée : `extrait_plat` (ruche_code, site_id, site_nom, pays, apicultrice, telephone, cooperative, horodatage, poids_kg, temp_int_c), 528 lignes.

Dépendances fonctionnelles retenues au lab 4 :

| # | Dépendance |
|---|---|
| DF1 | `site_id → site_nom, pays` |
| DF2 | `ruche_code → site_id, telephone` |
| DF3 | `telephone → apicultrice, cooperative` (vraie dans le jeu d'essai : chaque apicultrice adhère à une seule coopérative) |
| DF4 | `ruche_code, horodatage → poids_kg, temp_int_c` |

Seule clé candidate : **{ruche_code, horodatage}** (aucune DF ne détermine ruche_code ni horodatage, toute clé doit donc contenir les deux).

---

## 1. Les trois anomalies et la dépendance qui les cause

| Anomalie | Ce qu'on a fait (anomalies.sql) | Ce qui s'est passé | Dépendance en cause |
|---|---|---|---|
| **Mise à jour** | `Sénégal` → `Senegal` sur une seule ligne de SN-KOLD-011 ; nouveau téléphone sur une seule ligne de CI-YAMO-001 | L'enquête par pays passe de 3 à 4 pays ; la ruche CI-YAMO-001 a deux téléphones | **DF1** `site_id → pays` : le pays du site est recopié sur ses 144 lignes, une copie peut diverger. Pour le téléphone : **DF2** `ruche_code → telephone` (recopié sur 48 lignes) et, derrière, **DF3** (le téléphone porte l'apicultrice) |
| **Suppression** | Entre `BEGIN` et `ROLLBACK`, suppression des 48 mesures de SN-CASA-021 | Awa Diop (+221 77 100 00 02) disparaît : 0 ligne pour son téléphone | **DF3** `telephone → apicultrice, cooperative` (et DF2 qui relie la ruche au téléphone) : l'apicultrice n'existe qu'à travers les lignes de mesure de sa ruche |
| **Insertion** | Après `ADD PRIMARY KEY (ruche_code, horodatage)`, ajout du site CM-DOUA sans ruche | Refus : `null value in column "ruche_code" ... violates not-null constraint` | **DF1** `site_id → site_nom, pays` : un site est un fait indépendant, mais il ne peut être écrit que dans une ligne qui a une clé (ruche_code, horodatage), donc une mesure |

Remarque sur le téléphone : le numéro modifié (`+225 07 300 00 99`) est **nouveau**, il n'apparaît que sur une ligne. La dépendance `telephone → apicultrice` n'est donc pas contredite (ce numéro n'a qu'une apicultrice). C'est `ruche_code → telephone` qui l'est : la ruche CI-YAMO-001 a désormais deux téléphones. La requête de détection est donc `GROUP BY ruche_code HAVING count(DISTINCT telephone) > 1`.

## 2. Classement des dépendances par forme normale

| Forme normale | Règle | Vos dépendances qui la violent |
|---|---|---|
| 1NF | chaque case contient une seule valeur | **Aucune** : chaque case est atomique (un code, un nom, un pays, un téléphone, une date, un nombre) |
| 2NF | aucun attribut non premier ne dépend d'une **partie stricte** d'une clé candidate | **DF2** `ruche_code → site_id, telephone` : ruche_code n'est qu'une partie de la clé {ruche_code, horodatage}. Par transitivité, `site_nom, pays, apicultrice, cooperative` dépendent aussi de ruche_code seul (DF2 + DF1, DF2 + DF3) |
| 3NF | pour toute DF non triviale X → A, X est une superclé ou A est premier | **DF2** (une violation de la 2NF est aussi une violation de la 3NF), **DF1** `site_id → site_nom, pays` et **DF3** `telephone → apicultrice, cooperative` : colonne non clé → colonne non clé (dépendances transitives) |
| BCNF | toute DF non triviale a une superclé en partie gauche | **DF1, DF2, DF3** : leurs parties gauches `site_id`, `ruche_code`, `telephone` ne sont pas des superclés de extrait_plat. Seule DF4 (partie gauche = la clé) est conforme |

`extrait_plat` n'est donc qu'en 1NF.

Ici 3NF et BCNF coïncident : il n'y a qu'une clé candidate et aucun attribut premier (ruche_code, horodatage) en partie droite d'une DF.

## 3. Le découpage (migration_3nf.sql) : une table par déterminant

| Table | Déterminant / clé | Colonnes |
|---|---|---|
| `norm.site` | `site_id` (PK) | site_id, site_nom, pays |
| `norm.apicultrice` | `telephone` (PK) | telephone, apicultrice, cooperative |
| `norm.ruche` | `ruche_code` (PK) | ruche_code, site_id → norm.site, telephone → norm.apicultrice |
| `norm.mesure` | `(ruche_code, horodatage)` (PK) | ruche_code → norm.ruche, horodatage, poids_kg, temp_int_c |

Premier lancement sur les données corrompues : refus `duplicate key value violates unique constraint "site_pkey"` / `Key (site_id)=(SN-KOLD) already exists.` Après nettoyage (2 `UPDATE`, valeur majoritaire gardée) : `INSERT 0 4`, `INSERT 0 8`, `INSERT 0 11`, `INSERT 0 528`, soit 4 sites, 8 apicultrices, 11 ruches, 528 mesures, comme attendu.

Le squelette du TP fait du téléphone le déterminant de norm.apicultrice, ce qui le recopie dans norm.ruche (donnée personnelle, contraire à la minimisation). Un téléphone partagé, fréquent en zone rurale, casserait l'unicité ici, mais aussi le `telephone NOT NULL UNIQUE` de schema.sql : c'est une limite connue du modèle du jour 1. Évolution : retirer le `UNIQUE` et identifier l'apicultrice uniquement par son UUID, ce que schema.sql permet déjà puisque sa clé primaire est `id`.

## 4. Vérification BCNF table par table

| Table | Clé | Dépendances qui restent dans la table | Partie gauche = clé ? |
|---|---|---|---|
| `norm.site` | site_id | `site_id → site_nom, pays` | Oui |
| `norm.apicultrice` | telephone | `telephone → apicultrice, cooperative` | Oui |
| `norm.ruche` | ruche_code | `ruche_code → site_id, telephone` | Oui |
| `norm.mesure` | (ruche_code, horodatage) | `ruche_code, horodatage → poids_kg, temp_int_c` | Oui |

Pour le vérifier, on projette les DF sur chaque table : pour chaque ensemble X de colonnes de la table, on calcule X⁺ avec DF1 à DF4 et on ne garde que les colonnes de la table. Pour `norm.ruche` (ruche_code, site_id, telephone) :
- {telephone}⁺ ∩ {ruche_code, site_id, telephone} = {telephone} ;
- {site_id}⁺ ∩ {ruche_code, site_id, telephone} = {site_id} ;
- {site_id, telephone}⁺ n'atteint pas ruche_code.

La seule DF non triviale est donc `ruche_code → site_id, telephone`, avec la clé à gauche. Même calcul pour les trois autres tables. En termes métier : un site a plusieurs apicultrices, et `telephone → site_id` a été écartée au lab 4 (transhumance). Dans chaque table, la partie gauche de toute dépendance est la clé : **les 4 tables norm sont en BCNF** (donc aussi en 3NF et 2NF).

**Mise à jour après le retour de la prof (correction 4).** Depuis la clé étrangère composée `ruche_apicultrice_fk`, `telephone → site_id` est garantie par la base (dependances.md). Dans `norm.ruche (ruche_code, site_id, telephone)`, elle devient une dépendance transitive (`ruche_code → telephone → site_id`) : avec cette règle, `norm.ruche` est en 2NF mais plus en 3NF, et la version BCNF placerait `site_id` dans `norm.apicultrice`. Nous gardons les tables du lab 5 telles qu'elles ont été construites et vérifiées (contrôles 22 à 27 de `verif_rendu.sql`), avec l'hypothèse de l'époque. Dans `schema.sql`, `ruche.site_id` est de la même façon une redondance **contrôlée** : la clé composée l'empêche de diverger.

La décomposition est **sans perte** : la vue `norm.reconstruit` (jointure des 4 tables, mêmes colonnes dans le même ordre) comparée à `extrait_plat` par `EXCEPT` dans les deux sens donne **0 ligne**. Par le théorème de Heath, en trois étapes binaires (R = extrait_plat) :
1. DF1 : R = R[site_id, site_nom, pays] ⋈ R1, où R1 = R sans site_nom, pays ;
2. DF3 : R1 = R1[telephone, apicultrice, cooperative] ⋈ R2, où R2 = R1 sans apicultrice, cooperative ;
3. DF2 : R2 = R2[ruche_code, site_id, telephone] ⋈ R2[ruche_code, horodatage, poids_kg, temp_int_c].

Chaque étape est sans perte car l'attribut commun (site_id, telephone, ruche_code) détermine un des deux morceaux dans la relation courante. La conclusion dépend de DF3, hypothèse du jeu d'essai (lab 4) ; l'EXCEPT le confirme sur les 528 lignes. La décomposition **conserve** aussi les dépendances : chaque DF est portée par la clé primaire d'une table.

Attaques rejouées sur les tables norm :
- second pays pour SN-KOLD : **refusé** (`duplicate key value violates unique constraint "site_pkey"`) ;
- site CM-DOUA sans ruche : **accepté** (`INSERT 0 1`, fait entre `BEGIN` et `ROLLBACK`) ;
- supprimer les mesures d'une ruche ne supprime plus l'apicultrice (elle vit dans norm.apicultrice).

L'enquête par pays sur les tables norm redonne **3 pays** (96 + 144 + 288 = 528 mesures).

## 5. Conclusion

> Une seule ligne modifiée a fait passer l'enquête de 3 à 4 pays. Une base non normalisée ne peut pas servir de preuve.

(Lors de nos tests : avant l'UPDATE, Cameroun 96, Côte d'Ivoire 144, Sénégal 288 ; après, un pays « Senegal » de 1 mesure apparaît à côté de « Sénégal » 287. Les poids moyens changent à chaque rechargement car donnees.sql les tire au hasard ; les comptes, eux, ne changent pas.)

Dans le contexte Queen Bee, un attaquant ou une simple erreur de saisie sur **une** ligne fausse les statistiques par pays présentées aux bailleurs de BeeAfrica, sans qu'aucune contrainte ne proteste. Après découpage, le pays n'est écrit qu'une fois (norm.site) et la clé primaire refuse toute seconde version : l'intégrité est garantie par la base, pas par la discipline des utilisateurs.

---

## Testez-vous · Lab 5

1. **Un exemple de chacune des trois anomalies dans extrait_plat.**
   - *Mise à jour* : passer `pays` à `Senegal` sur une seule ligne de SN-KOLD-011 ; le site SN-KOLD a alors deux pays et l'enquête montre 4 pays au lieu de 3.
   - *Suppression* : supprimer les 48 mesures de SN-CASA-021 fait disparaître Awa Diop et son téléphone (c'était sa seule ruche).
   - *Insertion* : impossible d'ajouter le site CM-DOUA tant qu'il n'a ni ruche ni mesure (refus : `ruche_code` NULL dans la clé).

2. **Pourquoi `ruche_code → site_id` viole-t-il la 2NF ?** Parce que la clé de extrait_plat est {ruche_code, horodatage} et que site_id dépend de **ruche_code seul**, c'est-à-dire d'une partie de la clé. Le site est donc recopié sur les 48 mesures de chaque ruche au lieu d'être écrit une fois.

3. **Comment prouve-t-on en SQL qu'une décomposition est sans perte ?** On recompose la table d'origine par jointure des morceaux (vue `norm.reconstruit`), puis on compare dans les deux sens : `(extrait_plat EXCEPT reconstruit) UNION ALL (reconstruit EXCEPT extrait_plat)`. **0 ligne** = ni ligne perdue, ni ligne inventée (on vérifie aussi que les deux comptent 528 lignes, `EXCEPT` éliminant les doublons). Variante plus directe : `EXCEPT ALL` dans les deux sens, qui tient compte des doublons sans avoir besoin de compter.
