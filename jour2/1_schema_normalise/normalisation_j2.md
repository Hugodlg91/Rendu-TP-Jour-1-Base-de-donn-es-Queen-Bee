# normalisation_j2.md · TP Jour 2, Labs 6 et 7

Groupe : Praveen, Ugo, Hugo, Corentin

Les résultats ci-dessous ont été obtenus sur notre base du jour 1 (PostgreSQL 18). Le tableau des formations de l'énoncé a été adapté aux téléphones de nos apicultrices (correspondance en tête de `formation.sql`) : **Awa Diop (+221 77 100 00 02) joue le rôle de « Fatou Ba »**, avec le même numéro.

Les requêtes tapées dans psql sont rassemblées dans `requetes_j2.sql`, étape par étape, avec le résultat obtenu sur une base reconstruite (PostgreSQL 16). Ce fichier ne laisse rien dans la base (transactions annulées). Les temps et les poids tirés au hasard y diffèrent un peu des nôtres, c'est normal.

---

## Lab 6 · Décomposer sans rien perdre

### Étape 6.1 · Analyser la table reçue

`formation.sql` : `CREATE TABLE`, puis `INSERT 0 8`.

**Dépendances fonctionnelles**

| DF | En français |
|---|---|
| (`telephone`, `theme`) → `formateur` | pour un thème, une apicultrice n'a qu'un formateur, celui qui signe son attestation |
| `formateur` → `theme` | un formateur n'enseigne qu'un thème |

**Clés candidates**

- (`telephone`, `theme`) : sa fermeture donne `formateur`, donc les 3 colonnes ;
- (`telephone`, `formateur`) : `formateur` → `theme`, donc les 3 colonnes aussi.

Aucune n'a de sous-ensemble strict qui soit une clé. Par les fermetures : `telephone`⁺ = {`telephone`}, `theme`⁺ = {`theme`}, `formateur`⁺ = {`formateur`, `theme`}. Aucune ne donne les 3 colonnes, donc aucun attribut seul n'est une clé, et les deux clés sont minimales. Les données l'illustrent : `telephone` seul a plusieurs thèmes, et `theme` comme `formateur` seuls ont plusieurs apicultrices.

**Les trois tests sur les données** (`GROUP BY ... HAVING`, requêtes dans `requetes_j2.sql`) : 0 ligne chacun.
- (`telephone`, `theme`) → `formateur` : 0 ligne.
- `formateur` → `theme` : 0 ligne.
- (`telephone`, `formateur`) est bien une clé (pas de doublon) : 0 ligne.

**3NF ? Oui.** Toute colonne qui est en partie droite d'une DF est *première* : elle fait partie d'une clé. C'est le cas de `formateur` (clé 2) et de `theme` (clé 1), et la 3NF tolère une partie gauche non clé quand la partie droite est première.

**BCNF ? Non.** `formateur` → `theme` a une partie gauche, `formateur`, qui n'est pas une super-clé.

**L'anomalie** (entre `BEGIN` et `ROLLBACK`, requête dans `requetes_j2.sql`) : Moussa Sarr passe en `capteurs` sur la ligne de +221 77 100 00 02. La table l'accepte sans un mot, puis la recherche des formateurs à plusieurs thèmes renvoie :

```
  formateur  |     array_agg
-------------+-------------------
 Moussa Sarr | {capteurs,varroa}
```

La règle `formateur` → `theme` est violée : le thème de Moussa Sarr est écrit sur plusieurs lignes, et une seule copie a changé.

### Étape 6.2 · Découper, et prouver qu'on n'a rien perdu

**Le mauvais découpage** : `p1(telephone, theme)` et `p2(theme, formateur)`. La jointure donne **16 lignes au lieu de 8**, dont **8 inventées** (`EXCEPT`, requêtes dans `requetes_j2.sql`) :

```
     telephone     | theme  |   formateur
-------------------+--------+---------------
 +221 77 100 00 01 | varroa | Ibrahima Fall
 +221 77 100 00 01 | varroa | Kouassi Yao
 +221 77 100 00 02 | varroa | Ibrahima Fall
 +221 77 100 00 02 | varroa | Kouassi Yao
 +221 77 200 00 03 | varroa | Kouassi Yao
 +221 77 200 00 03 | varroa | Moussa Sarr
 +225 07 300 00 05 | varroa | Ibrahima Fall
 +225 07 300 00 05 | varroa | Moussa Sarr
```

Awa Diop (+221 77 100 00 02, notre « Fatou Ba ») serait suivie par trois formateurs varroa. **Pourquoi :** la colonne commune, `theme`, n'est la clé d'aucun des deux morceaux. Un thème a plusieurs apicultrices dans `p1` et plusieurs formateurs dans `p2`, donc la jointure associe chaque apicultrice à tous les formateurs du thème.

**Le bon découpage** : `formateur(id, nom UNIQUE, theme)` et `suivi_formation(apicultrice_id, formateur_id)`. La colonne commune est le formateur, clé de son morceau.
- Remplissage : `INSERT 0 5` (formateurs), puis `INSERT 0 8` (suivis).
- Double comparaison `EXCEPT` (recomposition par `suivi_formation` ⋈ `apicultrice` ⋈ `formateur`, requête dans `requetes_j2.sql`) : **0 ligne**. Rien de perdu, rien d'inventé.

**Quelle contrainte garantit `formateur` → `theme` ?** Le `UNIQUE` sur `formateur.nom`, avec la colonne `theme NOT NULL` dans la même ligne. Il n'existe qu'une ligne par formateur, donc un seul thème. Le `CHECK (theme IN ('varroa', 'recolte', 'capteurs'))` limite en plus les valeurs possibles.

**Pourquoi `suivi_formation` pointe-t-elle vers `apicultrice(id)` au lieu de recopier le téléphone ?**
- **Une seule copie** du téléphone, une donnée personnelle (minimisation) : si l'apicultrice change de numéro, rien d'autre n'est à corriger.
- **La clé étrangère garantit** que l'apicultrice existe ; un téléphone recopié pourrait désigner personne.
- **L'`id` ne change jamais** et ne révèle rien par lui-même, alors qu'un téléphone peut être partagé ou réattribué (limite connue du jour 1). Il reste pourtant une donnée personnelle, pseudonymisée : il désigne une personne, et la base permet de la retrouver.

### Étape 6.3 · La règle perdue, et le trigger qui la rétablit

**La règle perdue.** Après le découpage, plus aucune table ne contient à la fois l'apicultrice et le thème. Le trigger étant déjà dans `formation.sql`, nous l'avons désactivé dans une transaction annulée pour montrer ce que la base accepterait sans lui (requêtes dans `requetes_j2.sql`) :
- inscription d'Awa Diop chez Ibrahima Fall (varroa) : `INSERT 0 1` ;
- recherche des apicultrices qui ont deux formateurs pour un même thème :

```
   nom    | theme  |            array_agg
----------+--------+---------------------------------
 Awa Diop | varroa | {"Moussa Sarr","Ibrahima Fall"}
```

Puis `ROLLBACK` : la ligne fautive est supprimée.

**Le trigger** (`suivi_un_formateur_par_theme()`, trigger `suivi_formation_df`) :

```
-- Awa Diop chez Ibrahima Fall (varroa, elle a déjà Moussa Sarr)
ERROR:  DF violée : cette apicultrice a déjà un formateur pour ce thème
-- Awa Diop chez Khady Ndiaye (récolte, thème nouveau pour elle)
INSERT 0 1
```

**Une limite du modèle repris de GreenFarm.** La condition `s.formateur_id <> NEW.formateur_id` refuse à tort un changement légitime : remplacer le formateur d'une apicultrice par un autre du même thème. Pour Awa Diop, avec la fonction de `formation.sql`, `UPDATE suivi_formation SET formateur_id = <Ibrahima Fall>` sur sa ligne Moussa Sarr répond `DF violée` (requête dans `requetes_j2.sql`). L'ancienne version de la ligne (Moussa Sarr, varroa) est encore visible, et son formateur est bien différent du nouveau. Il faut exclure la ligne elle-même (`OLD`), ce que fait la version de `corrections.sql` : après elle, le même remplacement répond `UPDATE 1`. Nous gardons dans `formation.sql` la version de l'énoncé.

**La règle était aussi contournable par la table `formateur`.** Le trigger ne surveille que `suivi_formation`, or le thème est lu dans `formateur`. Sans autre garde, `UPDATE formateur SET theme = 'varroa' WHERE nom = 'Khady Ndiaye'` passait sans message, et Aminata Diop (+221 77 100 00 01) se retrouvait avec deux formateurs varroa, Khady Ndiaye et Moussa Sarr. Nous avons ajouté à la fin de `formation.sql` un second trigger, `formateur_theme_df` (`BEFORE UPDATE OF theme ON formateur`), qui refuse ce changement :

```
ERROR:  DF violée : Khady Ndiaye ne peut pas passer en varroa, une de ses apicultrices a déjà un formateur pour ce thème
```

Un changement de thème sans conflit passe toujours (Kouassi Yao en capteurs : `UPDATE 1`). Une règle portée par trigger doit donc surveiller **toutes** les tables d'où elle lit ses données : c'est un argument de plus pour la variante à contrainte ci-dessous, où la clé étrangère composée fait ce travail toute seule.

**Pour aller plus loin : la même garantie sans trigger.** On recopie le thème dans le suivi, avec `UNIQUE (apicultrice_id, theme)` et une clé étrangère composée `(formateur_id, theme) REFERENCES formateur (id, theme)`, qui demande `UNIQUE (id, theme)` sur `formateur`. Testé dans une transaction annulée (requêtes dans `requetes_j2.sql`) :
- Awa Diop + Ibrahima Fall (varroa) : `duplicate key value violates unique constraint "suivi_formation_v2_apicultrice_id_theme_key"` ;
- Moussa Sarr déclaré « capteurs » pour tricher sur le thème : `violates foreign key constraint "suivi_formation_v2_formateur_id_theme_fkey"` ;
- Khady Ndiaye passée en varroa par la table `formateur` (second trigger désactivé) : refusé aussi par cette clé étrangère, car le thème est encore référencé dans `suivi_formation_v2`.

**Est-ce encore en BCNF ? Non.** Dans `suivi_formation_v2(apicultrice_id, formateur_id, theme)`, `formateur_id` → `theme` alors que `formateur_id` n'est pas une super-clé. Les clés sont (`apicultrice_id`, `formateur_id`) et (`apicultrice_id`, `theme`). La table est en **3NF** (`theme` est premier), comme `formation_plat`. Mais la copie du thème ne peut plus diverger, puisque la clé étrangère composée l'oblige à rester égale au thème du formateur. On accepte une redondance **contrôlée** pour que la règle soit portée par un index unique, qui résiste aux insertions simultanées, contrairement au trigger (lab 9, `concurrence.md`).

La correction du trigger dans `corrections.sql` (verrou sur la ligne de l'apicultrice) ne vaut qu'en `READ COMMITTED`, le niveau par défaut : la seconde inscription attend, puis relit les lignes validées. En `REPEATABLE READ`, elle garde sa photo du début de transaction et ne voit pas la première : essayé avec deux sessions sur Mariama Ba (Moussa Sarr, puis Ibrahima Fall), les deux inscriptions passent. En `SERIALIZABLE`, la seconde échoue, mais par le contrôle de sérialisation de PostgreSQL (`could not serialize access`), pas grâce au verrou. La contrainte `UNIQUE`, elle, tient à tout niveau d'isolation.

### Étape 6.4 · Revue BCNF de tout le schéma

Méthode : pour chaque table, la clé primaire détermine tout, et chaque `UNIQUE` aussi. On cherche ensuite une autre DF dont la partie gauche ne serait pas une super-clé.

| Table | Dépendances | Partie gauche = super-clé ? | BCNF ? |
|---|---|---|---|
| `site` | `id` → `nom`, `pays` | oui | oui |
| `cooperative` | `id` → `nom`, `site_id` | oui | oui |
| `apicultrice` | `id` → tout ; `telephone` (UNIQUE) → tout | oui (deux clés) | oui |
| `ruche` | `id` → tout ; `code` (UNIQUE) → tout ; `apicultrice_id` → `site_id` (correction 4 du jour 1) | non pour `apicultrice_id` → `site_id` | **non** : `site_id` est une copie **contrôlée** du site de l'apicultrice (voir ci-dessous) |
| `adhesion` | (`apicultrice_id`, `cooperative_id`) → `date_adhesion` | oui | oui |
| `utilisateur` | `id` → tout ; `login` (UNIQUE) → tout ; `apicultrice_id` (UNIQUE, quand il est rempli) → tout | oui | oui (mais `site_id` recopie un fait d'une autre table, voir ci-dessous) |
| `mesure` | `id` → tout ; (`ruche_id`, `horodatage`) (UNIQUE anti-rejeu) → tout | oui | oui |
| `inspection` | `id` → tout | oui | oui (`apicultrice_id` n'est pas une copie, voir ci-dessous) |
| `recolte` | `id` → tout | oui | oui |
| `alerte` | `id` → tout | oui | oui |
| `formateur` | `id` → `nom`, `theme` ; `nom` (UNIQUE) → `id`, `theme` | oui | oui |
| `suivi_formation` | aucune DF non triviale (clé = les deux colonnes) | oui | oui |
| `jeton` (créée au lab 9, `jeton.sql`) | `id` → tout ; `valeur` (UNIQUE) → tout | oui | oui |
| `session_app` (créée au lab 9, `jeton.sql`) | `id` → tout ; `jeton_id` (UNIQUE, lab 9) → tout | oui | oui |
| `journal_audit` | `id` → tout | oui | oui |
| `cle_pseudonymisation` | `id` → `cle` (une seule ligne) | oui | oui |
| `synthese_site_jour` (vue matérialisée) | (`site_id`, `jour`) → agrégats | oui | oui, mais c'est une **copie voulue** (lab 7) |
| `formation_plat` | `formateur` → `theme` | **non** | **non** : gardée comme trace du fichier reçu ; la donnée de travail est dans `formateur` et `suivi_formation`. Elle garde une **seconde copie des téléphones** : il faudrait la vider après l'import, ou la fermer à tous avec une durée de conservation |
| `extrait_plat` (jour 1) | DF1 à DF3 du jour 1 | non | non : table d'exercice du jour 1 (1NF seulement) ; les tables `norm.*` sont en BCNF avec l'hypothèse du lab 5 (lignes suivantes) |
| `norm.site` (jour 1) | `site_id` → `site_nom`, `pays` | oui | oui |
| `norm.apicultrice` (jour 1) | `telephone` → `apicultrice`, `cooperative` | oui (la clé est `telephone`) | oui, mais la clé est une donnée personnelle (limite du jour 1) |
| `norm.ruche` (jour 1) | `ruche_code` → `site_id`, `telephone` ; depuis la correction 4, aussi `telephone` → `site_id` | non pour `telephone` → `site_id` | oui avec l'hypothèse du lab 5 ; **non** depuis la correction 4 (2NF seulement, `normalisation.md` du jour 1) |
| `norm.mesure` (jour 1) | (`ruche_code`, `horodatage`) → `poids_kg`, `temp_int_c` | oui | oui |

Les tables `norm.*` et `extrait_plat` sont des tables d'exercice du jour 1 : chacune est en BCNF (ou pas) pour elle-même, mais ensemble elles recopient des données de `public` (dont les téléphones). Elles n'ont pas leur place dans une base de production.

**`apicultrice.site_id` et `ruche.site_id` : le même fait écrit deux fois ?** Pour chaque apicultrice, le site de ses ruches (requête dans `requetes_j2.sql`) :

```
      nom       | site_apicultrice | sites_ruches
----------------+------------------+--------------
 Adjoua Kouassi | CI-YAMO          | {CI-YAMO}
 Aya Kone       | CI-YAMO          | {CI-YAMO}
 Brigitte Ngono | CM-BAFO          | {CM-BAFO}
 Esther Fotso   | CM-BAFO          | {CM-BAFO}
 Aminata Diop   | SN-CASA          | {SN-CASA}
 Awa Diop       | SN-CASA          | {SN-CASA}
 Aminata Diop   | SN-KOLD          | {SN-KOLD}
 Mariama Ba     | SN-KOLD          | {SN-KOLD}
(8 lignes)
```

Chaque apicultrice n'a de ruches que sur son site.

**Règle métier ou coïncidence ?** Règle métier : une ruche est sur le site de son apicultrice. La **transhumance planifiée** (UC-CY04) déplace bien une ruche pour un temps vers un autre site, mais depuis la correction 4 du jour 1 (retour de la prof), elle sera une entité à part, TRANSHUMANCE (`annotations.md` du jour 1, question 4). `ruche.site_id` est donc le site de **rattachement** de la ruche, toujours égal à `apicultrice.site_id` : c'est une DF stricte. Le `schema.sql` du jour 1 l'impose par une clé étrangère composée (`apicultrice_id`, `site_id`) vers `apicultrice (id, site_id)`, qui s'appuie sur `apicultrice_id_site_uq UNIQUE (id, site_id)`.

**Ce qui garantit la cohérence dans notre schéma** : cette clé étrangère composée, `ruche_apicultrice_fk`. Le test 7 du jour 1 le montre (`tests_schema.sql` : une ruche déclarée hors du site de son apicultrice est refusée). `ruche.site_id` est donc une copie **contrôlée**, comme le thème de `suivi_formation_v2` : elle ne peut pas diverger. La détection d'un déplacement non déclaré repose toujours sur la position GPS des mesures ; l'entité TRANSHUMANCE (ruche, site de destination, période) dira où se trouve la ruche pendant une transhumance.

**Une vraie copie : `utilisateur.site_id`.** Pour un compte du rôle `apicultrice`, `site_id` recopie `apicultrice.site_id` (le compte est rattaché au site de son apicultrice). Comme pour la ruche, pas d'exception métier ; mais ici, c'est une copie qui peut diverger. Aujourd'hui les deux sont égaux (0 ligne, requête dans `requetes_j2.sql`), mais rien ne l'impose. Les vues filtrées du lab 8 lisent `utilisateur.site_id` pour le coordinateur ; celles de l'apicultrice passent par `apicultrice_id`, donc un site faux sur son compte n'ouvre rien aujourd'hui. Mais `v_moi` l'affiche, et toute future vue ou règle de sécurité par site (RLS) le lirait : un compte rattaché au mauvais site verrait alors les données d'un autre site. Deux corrections possibles :
- imposer `site_id IS NULL` pour le rôle `apicultrice` (il faut alors modifier le `CHECK` `utilisateur_site_si_terrain`, qui l'exige aujourd'hui) et lire le site par la jointure avec `apicultrice` ;
- ou garder la colonne, avec une clé étrangère composée (`apicultrice_id`, `site_id`) → `apicultrice (id, site_id)`, qui s'appuierait sur la même `apicultrice_id_site_uq`, déjà posée au jour 1 pour la ruche (correction 4). C'est la limite 2 de notre jour 1 (`RENDU.md`), déjà testée dans une transaction annulée.

**Pas une copie : `inspection.apicultrice_id`.** Elle désigne l'apicultrice qui a fait l'inspection, pas forcément la propriétaire de la ruche (entraide entre voisines, hypothèse du jour 1, `annotations.md` question 4). Ce n'est pas `ruche.apicultrice_id` écrit deux fois.

### Testez-vous · Lab 6

1. **R(A, B, C) avec A → B.** (A, B) + (A, C) est **sans perte** : la colonne commune A est la clé de (A, B), puisque A → B (théorème de Heath). (A, B) + (B, C) **peut inventer des lignes** : la colonne commune B n'est la clé d'aucun morceau. Rien ne dit B → A ni B → C, et un même B peut avoir plusieurs A et plusieurs C.
2. **Pourquoi `formation_plat` est-elle en 3NF ?** La 3NF accepte X → A quand X n'est pas une super-clé, à condition que A soit *premier*, c'est-à-dire membre d'une clé candidate. `theme` appartient à la clé (`telephone`, `theme`) : la 3NF est respectée. La BCNF, plus stricte, exige une super-clé à gauche, sans exception.
3. **Pourquoi `s.formateur_id <> NEW.formateur_id` ?** Le trigger est aussi `BEFORE UPDATE`. Lors d'un `UPDATE`, l'ancienne version de la ligne est encore visible. Sans cette condition, un `UPDATE` qui garde la même apicultrice et un formateur du même thème (le même formateur, ou un autre du même thème) trouverait sa propre ancienne version et serait refusé à tort. Un `UPDATE` vers un formateur d'un autre thème passerait, lui : ce n'est donc pas « tout `UPDATE` ». À l'insertion, le doublon exact (même formateur) relève de la clé primaire, pas de cette règle.
   Mais la condition ne suffit pas : pour un changement de formateur dans le même thème (Moussa Sarr remplacé par Ibrahima Fall), l'ancienne version a un autre `formateur_id`, elle est donc trouvée, et le remplacement est refusé à tort (étape 6.3). La bonne condition exclut la ligne elle-même (`OLD`) : c'est la version de `corrections.sql`.
4. **Rester en 3NF plutôt que BCNF.**
   - Avantage : la DF (`telephone`, `theme`) → `formateur` reste portée par la clé primaire, donc vérifiée par un index unique, sans trigger, y compris pour des insertions simultanées.
   - Inconvénient : `formateur` → `theme` est recopiée sur plusieurs lignes, d'où l'anomalie de mise à jour (Moussa Sarr avec deux thèmes, sans aucun message).
