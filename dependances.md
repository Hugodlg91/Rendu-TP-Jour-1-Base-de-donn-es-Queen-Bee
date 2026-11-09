# Dépendances fonctionnelles – Groupe Praveen, Ugo, Hugo, Corentin

> `dependances.md` · TP Jour 1, Lab 4 (étapes 4.2, 4.3 et 4.4)
> Table étudiée : `extrait_plat` (créée par `plat.sql`, 528 lignes, 10 colonnes) :
> `ruche_code`, `site_id`, `site_nom`, `pays`, `apicultrice`, `telephone`, `cooperative`, `horodatage`, `poids_kg`, `temp_int_c`.

## Les DF de extrait_plat

| DF | En français |
|----|-------------|
| `site_id` → `site_nom`, `pays` | un site a un seul nom et un seul pays |
| `ruche_code` → `site_id`, `telephone` | une ruche est sur un seul site et appartient à une seule apicultrice (repérée par son téléphone) |
| `telephone` → `apicultrice`, `cooperative` | un téléphone désigne une seule apicultrice et sa coopérative (**hypothèse**, voir ci-dessous) |
| `ruche_code`, `horodatage` → `poids_kg`, `temp_int_c` | une seule mesure par ruche et par instant (c'est la règle anti-rejeu `mesure_anti_rejeu`) |

**Hypothèse sur `telephone` → `cooperative`.** Dans le MCD, l'adhésion est une association **n,n** : une apicultrice peut adhérer à plusieurs coopératives. Cette partie de la DF n'est donc **pas une règle métier** ; elle n'est vraie que **dans notre jeu d'essai**, où chaque apicultrice adhère à une seule coopérative (celle de son site). Si une apicultrice adhérait à deux coopératives, `plat.sql` produirait deux lignes par mesure avec deux coopératives différentes, et la DF tomberait. Il y aurait alors une ligne par adhésion : {`ruche_code`, `horodatage`} ne serait plus une clé (la clé deviendrait {`ruche_code`, `horodatage`, `cooperative`}, avec une dépendance multivaluée `telephone` ↠ `cooperative`, sujet de la 4NF). Toute la suite (clé, formes normales, découpage) est donc **conditionnelle à cette hypothèse**. La partie `telephone` → `apicultrice` est, elle, garantie par la base (le téléphone est `UNIQUE` dans `apicultrice`), avec la limite du téléphone partagé (normalisation.md § 3).

Pourquoi garder DF3 et pas `telephone` → `site_id`, alors que les deux ne sont vraies que sur les données ? Parce que le squelette du TP la suppose (`norm.apicultrice` a `telephone` pour clé et une seule colonne `cooperative`), alors que `telephone` → `site_id` est contredite par une règle métier écrite (la transhumance, voir ci-dessous). DF3 reste une hypothèse de travail.

**Dépendance écartée : `telephone` → `site_id`.** Dans `extrait_plat`, `site_id` est le site **de la ruche** (`plat.sql` joint `s.id = r.site_id`), pas `apicultrice.site_id`. Les données ne la contredisent pas (0 ligne dans `contraintes.sql`), mais ce n'est pas une règle métier : pendant une transhumance déclarée (hypothèse du lab 1, UC-CY04), une ruche peut se trouver sur un autre site que celui de son apicultrice, et un même téléphone aurait alors deux `site_id`. Nous ne la retenons donc pas : c'est un nouvel exemple où « 0 ligne » ne prouve pas une DF (Testez-vous 3). Si on la retenait, `ruche_code` → `site_id` deviendrait déductible (`ruche_code` → `telephone` → `site_id`), et le site devrait aller dans `norm.apicultrice` et non dans `norm.ruche`.

**DF fausse :** `apicultrice` → `telephone`. Le nom ne détermine pas la personne : « Aminata Diop » a deux téléphones (`+221 77 100 00 01` à SN-CASA, `+221 77 200 00 03` à SN-KOLD). Résultat dans `contraintes.sql`.

## Trois fermetures et la clé

### {site_id}⁺

| Tour | DF utilisée | {site_id}⁺ |
|------|-------------|------------|
| 0 | aucune | {site_id} |
| 1 | `site_id` → `site_nom`, `pays` | + site_nom, pays |
| 2 | plus rien ne s'ajoute | **3 colonnes sur 10 : pas une clé** |

### {ruche_code}⁺

| Tour | DF utilisée | {ruche_code}⁺ |
|------|-------------|---------------|
| 0 | aucune | {ruche_code} |
| 1 | `ruche_code` → `site_id`, `telephone` | + site_id, telephone |
| 2 | `site_id` → … ; `telephone` → … | + site_nom, pays, apicultrice, cooperative |
| 3 | plus rien ne s'ajoute | **7 colonnes sur 10 : pas une clé** |

Il manque `horodatage`, `poids_kg` et `temp_int_c` : une ruche a 48 mesures dans la journée, donc 48 lignes avec le même `ruche_code`.

### {ruche_code, horodatage}⁺

| Tour | DF utilisée | {ruche_code, horodatage}⁺ |
|------|-------------|---------------------------|
| 0 | aucune | {ruche_code, horodatage} |
| 1 | `ruche_code` → `site_id`, `telephone` ; `ruche_code`, `horodatage` → `poids_kg`, `temp_int_c` | + site_id, telephone, poids_kg, temp_int_c |
| 2 | `site_id` → … ; `telephone` → … | + site_nom, pays, apicultrice, cooperative |
| 3 | plus rien ne s'ajoute | **10 colonnes sur 10 : c'est une clé** |

### La clé candidate

**{`ruche_code`, `horodatage`}** est la clé candidate de `extrait_plat`. On ne peut rien en retirer :

- sans `horodatage`, {`ruche_code`}⁺ ne donne que 7 colonnes sur 10 (48 mesures par ruche) ;
- sans `ruche_code`, {`horodatage`}⁺ = {`horodatage`} : aucune DF n'a `horodatage` seul à gauche (le même instant est partagé par les 11 ruches du jeu d'essai).

La clé est donc **minimale**.

Elle est aussi la **seule** clé candidate : `ruche_code` et `horodatage` n'apparaissent dans aucune partie droite de DF, donc toute clé les contient tous les deux ; {`ruche_code`, `horodatage`} étant déjà une clé, il n'y en a pas d'autre.

Vérification sur les données : 528 lignes et 528 couples (`ruche_code`, `horodatage`) distincts. C'est exactement la contrainte `mesure_anti_rejeu UNIQUE (ruche_id, horodatage)` posée au lab 2.

## Que se passerait-il si l'application identifiait les apicultrices par leur nom ?

Le nom n'est pas une clé : deux « Aminata Diop » existent (SN-CASA et SN-KOLD). Une application qui chercherait « l'apicultrice Aminata Diop » prendrait l'une pour l'autre :

- **mauvaise personne contactée** : une alerte de vol ou d'essaimage sur SN-KOLD-011 envoyée à l'Aminata Diop de Casamance, pendant que la vraie propriétaire n'est pas prévenue ;
- **données attribuées à la mauvaise personne** : ruches, inspections ou récoltes rattachées à l'autre, donc des statistiques fausses, et des paiements de récolte qui partent vers la mauvaise apicultrice (**T**, altération de l'intégrité) ;
- **fuite de données personnelles** : l'une verrait le téléphone, les positions GPS des ruches et les récoltes de l'autre (**I** de STRIDE) ;
- **usurpation d'identité** : il suffirait de s'appeler (ou de se dire) « Aminata Diop » pour agir sous l'identité de l'homonyme (**S** de STRIDE), et on ne saurait plus qui a fait quoi (**R**).

D'où la règle : on identifie toujours une apicultrice par une **clé** (son `id`, ou son `telephone`, qui est `UNIQUE` dans schema.sql), jamais par son nom. Le mieux reste l'`id` : un téléphone partagé casserait le `UNIQUE` (limite connue du modèle du jour 1, voir normalisation.md § 3). C'est aussi pourquoi le login `a.diop`, fabriqué à partir du nom, doit devenir unique (étape 4.4).

## Testez-vous · Lab 4

1. **Que veut dire `site_id` → `pays` ?**
   Si on connaît le site, on connaît son pays : un site est dans un seul pays. Deux lignes avec le même `site_id` ont forcément le même `pays`.

2. **Pourquoi {`ruche_code`} n'est-il pas une clé de `extrait_plat` ?**
   Sa fermeture ne donne que 7 colonnes sur 10 : il manque `horodatage`, `poids_kg` et `temp_int_c`. Une ruche envoie une mesure toutes les 30 minutes (48 lignes par ruche), donc `ruche_code` se répète et ne désigne pas une seule ligne.

3. **Pourquoi « 0 ligne » ne prouve-t-il pas qu'une DF est vraie ?**
   « 0 ligne » dit seulement que les données d'**aujourd'hui** ne contredisent pas la règle. Une DF est une règle métier, valable pour **toutes** les données, y compris futures ; un petit jeu d'essai peut la vérifier par hasard. Exemple : `telephone` → `cooperative` donne 0 ligne ici, mais elle tombera dès qu'une apicultrice adhérera à une deuxième coopérative (adhésion n,n). À l'inverse, une seule ligne suffit à prouver qu'une DF est fausse. La vraie garantie, c'est une contrainte dans la base (`UNIQUE`, clé primaire).
