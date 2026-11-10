# annotations.md · TP Jour 1, Labs 1 et 2 · Modèle entité-association – Queen Bee

Groupe : Praveen, Ugo, Hugo, Corentin

Sources : sujet du TP Jour 1 + cahier des charges fonctionnel Queen Bee (CDC, janvier 2027).
Les références « UC-xxx » renvoient aux cas d'utilisation du CDC.

---

## Question 1 · De quoi le système doit-il se souvenir ?

Les « choses » sur lesquelles on garde plusieurs informations :

1. **site** (site rucher)
2. **coopérative**
3. **apicultrice**
4. **ruche**
5. **mesure** (trame envoyée par les capteurs de la ruche)
6. **inspection**
7. **récolte**
8. **alerte**
9. **utilisateur** (compte de connexion)

**9 choses.**

Ce qui n'en est pas une (dans le modèle du TP) :
- le **pays** : c'est une information sur le site (3 pays seulement, rien d'autre à garder dessus) ;
- le **capteur** : le CDC parle de « capteurs associés » à la ruche, mais on ne garde rien sur eux en propre ; ils sont portés par la ruche (une évolution possible plus tard : une entité CAPTEUR avec numéro de série et certificat) ;
- la **température**, le **poids**, la **batterie** : ce sont des informations sur la mesure ;
- le **coordinateur**, le **gestionnaire**, l'**administrateur** : ce sont des rôles d'utilisateur, pas des entités séparées.

**Deux entités sans équivalent dans GreenFarm : RÉCOLTE et ALERTE.**
- RÉCOLTE : le miel est la production que l'apicultrice déclare puis que le coordinateur valide en la comparant aux données de poids des capteurs (UC-A03, UC-C02). C'est un enjeu de revenus pour les coopératives et un risque de fraude (fausses déclarations).
- ALERTE : le système détecte des risques (essaimage, vol, capteur silencieux, stress thermique…) et doit en garder une trace avec un niveau de confiance et un statut de traitement (UC-A02).

---

## Question 2 · Que garde-t-on sur chacune, et qu'est-ce qui la distingue ?

| Chose | Ce qu'on garde | Ce qui la distingue |
|---|---|---|
| site | nom, pays | un code lisible (ex. `SN-CASA`), stocké dans `id` |
| coopérative | nom | un numéro attribué |
| apicultrice | nom, téléphone | un numéro attribué (deux « Aminata Diop » : le nom ne suffit pas) |
| ruche | code, position GPS de référence (latitude, longitude), date d'installation | un numéro attribué (le code `SN-CASA-014` est unique aussi) |
| mesure | horodatage, poids, température intérieure, température extérieure, humidité, score d'activité acoustique, batterie, position GPS reçue | un numéro technique (id_mesure) ; la ruche et l'horodatage forment l'identifiant alternatif |
| inspection | date, état de la colonie, présence de la reine, observations, photo | un numéro attribué |
| récolte | date, quantité, statut (déclarée / validée / écart signalé), date de validation | un numéro attribué |
| alerte | type (essaimage, vol / déplacement, capteur silencieux, stress thermique, mortalité), date, niveau de confiance, statut de traitement (ouverte / en cours / fermée) | un numéro attribué |
| utilisateur | login (identifiant), mot de passe (haché), rôle | un numéro attribué |

Remarques tirées du CDC :
- la mesure contient la **position GPS** à chaque trame : on la compare à la position de référence de la ruche pour détecter un vol (UC-CY04) ;
- le son brut n'est jamais stocké : seul un **score d'activité** calculé en local est transmis (§ 6.4) ;
- l'**écart à la prédiction** d'une récolte se calcule (prédiction du modèle de l'équipe Data − quantité déclarée), on ne le stocke pas dans le MCD ;
- l'identifiant technique `id_mesure` de la **mesure** vient du très gros volume (jamais exposé) ; l'identifiant alternatif (ruche, horodatage) est mis en œuvre par la contrainte `mesure_anti_rejeu` ;
- la **MFA** est gérée par l'application (hors modèle de données) : on ne la met pas dans les attributs, mais elle reste une protection dans STRIDE.

---

## Question 3 · Comment sont-elles liées ?

| Lien | Dans un sens | Dans l'autre sens |
|---|---|---|
| ruche – apicultrice | une ruche appartient à **une seule** apicultrice | une apicultrice possède **zéro, une ou plusieurs** ruches |
| site – ruche | une ruche est installée sur **un seul** site | un site accueille **zéro, une ou plusieurs** ruches |
| apicultrice – site | une apicultrice est rattachée à **un seul** site | un site regroupe **zéro, une ou plusieurs** apicultrices |
| apicultrice – coopérative | une apicultrice adhère à **une ou plusieurs** coopératives | une coopérative a **zéro, une ou plusieurs** adhérentes |
| coopérative – site | une coopérative est implantée sur **un seul** site | un site accueille **zéro, une ou plusieurs** coopératives |
| ruche – mesure | une ruche émet **zéro, une ou plusieurs** mesures | une mesure provient d'**une seule** ruche |
| ruche – inspection | une ruche reçoit **zéro, une ou plusieurs** inspections | une inspection concerne **une seule** ruche |
| apicultrice – inspection | une apicultrice réalise **zéro, une ou plusieurs** inspections | une inspection est réalisée par **une seule** apicultrice |
| ruche – récolte | une ruche donne **zéro, une ou plusieurs** récoltes | une récolte provient d'**une seule** ruche |
| ruche – alerte | une ruche déclenche **zéro, une ou plusieurs** alertes | une alerte concerne **une seule** ruche |
| utilisateur (coordinateur) – récolte | un coordinateur valide **zéro, une ou plusieurs** récoltes | une récolte est validée par **au plus un** coordinateur (aucun tant qu'elle est seulement déclarée) |
| apicultrice – compte de connexion | une apicultrice a **au plus un** compte | un compte appartient **au plus à une** apicultrice (les comptes coordinateur, gestionnaire et admin n'ont pas d'apicultrice) |
| compte de connexion – site | un compte est affecté à **au plus un** site (coordinateur ou apicultrice ; le gestionnaire et l'admin n'en ont pas besoin) | un site a **zéro, un ou plusieurs** comptes affectés |

### Associations du MCD (pour le dessin draw.io)

| Association | Entité A (card.) | Entité B (card.) | Attribut porté |
|---|---|---|---|
| POSSÈDE | APICULTRICE 0,n | RUCHE 1,1 | |
| ACCUEILLE | SITE 0,n | RUCHE 1,1 | |
| EST RATTACHÉE | SITE 0,n | APICULTRICE 1,1 | |
| ADHÈRE | APICULTRICE 1,n | COOPÉRATIVE 0,n | date_adhesion |
| EST IMPLANTÉE | SITE 0,n | COOPÉRATIVE 1,1 | |
| ÉMET | RUCHE 0,n | MESURE 1,1 | |
| CONCERNE | RUCHE 0,n | INSPECTION 1,1 | |
| RÉALISE | APICULTRICE 0,n | INSPECTION 1,1 | |
| PRODUIT | RUCHE 0,n | RÉCOLTE 1,1 | |
| VALIDE | UTILISATEUR 0,n | RÉCOLTE 0,1 | |
| DÉCLENCHE | RUCHE 0,n | ALERTE 1,1 | |
| A POUR COMPTE | APICULTRICE 0,1 | UTILISATEUR 0,1 | |
| EST AFFECTÉ | UTILISATEUR 0,1 | SITE 0,n | |

13 associations ; une seule (ADHÈRE) a n des deux côtés et porte une date.

Contrainte entre associations : le compte qui valide une récolte doit être affecté au site de la ruche (VALIDE puis EST AFFECTÉ doit donner le même site que PRODUIT puis ACCUEILLE). Les cardinalités ne peuvent pas l'exprimer (limite 1 de tests_schema.sql).

---

## Question 4 · Qu'est-ce que le sujet ne dit pas ?

Certaines questions trouvent une réponse dans le CDC : on l'indique.

| Question au client | Notre hypothèse |
|---|---|
| Une ruche peut-elle changer de site ? | Oui : le CDC prévoit la **transhumance planifiée** par l'apicultrice (UC-CY04). Elle deviendra une entité TRANSHUMANCE (ruche, site de destination, période) : `ruche.site_id` reste le site de rattachement, celui de l'apicultrice. On ne garde que la position de référence actuelle ; un déplacement non déclaré déclenche une alerte de vol |
| Une ruche peut-elle être sur un autre site que celui de son apicultrice ? | Non. Depuis la correction 4 (retour de la prof), la base l'impose : la clé étrangère composée `ruche_apicultrice_fk (apicultrice_id, site_id)` → `apicultrice (id, site_id)` refuse une ruche hors du site de son apicultrice (test 7 du lab 2). Un séjour sur un autre site pendant une transhumance sera enregistré dans la future entité TRANSHUMANCE, sans changer `ruche.site_id` |
| Qui peut valider une récolte ? | Le coordinateur **du site de la ruche** uniquement (8 coordinateurs régionaux pour 8 sites, CDC § 1.4 ; le jeu d'essai ne compte que 4 sites et un coordinateur). Il compare la déclaration au poids mesuré par les capteurs, puis valide ou signale un écart (UC-C02). Une apicultrice ne valide jamais sa propre récolte |
| Une récolte validée peut-elle encore être modifiée ? | Non : une fois validée, elle est figée (seul l'admin peut corriger, et l'action est tracée) |
| Une ruche est-elle rattachée à une coopérative ? | Le CDC (§ 7.1) le suggère, mais la coopérative n'est **pas déductible de façon unique** : ADHÈRE est 1,n (une apicultrice peut adhérer à plusieurs coopératives) et un site peut avoir plusieurs coopératives. C'est hors périmètre du MCD du jour 1 ; si le client le confirme, il faudrait une association directe RUCHE (1,1) – RELÈVE DE – COOPÉRATIVE (0,n) |
| Une apicultrice peut-elle adhérer à une coopérative d'un autre site que le sien ? | Oui, on le suppose (une coopérative peut regrouper des apicultrices de sites voisins) ; le modèle ne l'interdit d'ailleurs pas (le cycle APICULTRICE – SITE – COOPÉRATIVE n'est pas contraint) |
| Une inspection peut-elle être faite par une autre apicultrice que la propriétaire de la ruche ? | Oui, on le suppose, mais seulement par une apicultrice **du site de la ruche** (entraide entre voisines) ; sinon RÉALISE serait redondant avec CONCERNE puis POSSÈDE. Le modèle ne l'impose pas (limite 6 de tests_schema.sql) |
| Une ruche peut-elle changer d'apicultrice ? | Oui, mais on ne garde que l'apicultrice actuelle |
| Qui ferme une alerte ? Garde-t-on les alertes fermées ? | Le coordinateur du site (ou le gestionnaire pour les alertes critiques) ; les alertes fermées sont conservées |
| À quelle fréquence arrivent les mesures ? | Le TP dit 30 min, le CDC 15 min (et 5 min en surveillance renforcée). On suit le TP pour le jeu d'essai (48 mesures par jour) ; le modèle accepte n'importe quelle fréquence |
| Combien de temps garde-t-on les mesures ? | Tout l'historique est conservé (« historique complet », CDC § 7.2) |

---

## Question 5 · Qu'est-ce qui intéresserait un voleur ou un fraudeur ?

1. **La position GPS des ruches** (référence et position reçue dans chaque mesure) : un voleur sait exactement où aller pour voler les ruches ou les récoltes.
2. **Le téléphone des apicultrices** : hameçonnage, arnaque (se faire passer pour l'association), démarchage. C'est une donnée personnelle de bénéficiaires vulnérables (RGPD, minimisation, CDC § 8.4).
3. **Les récoltes (quantité, validation)** : déclarer plus de miel que la réalité, ou faire valider une récolte sans contrôle, pour toucher des aides ou détourner du miel.
4. *(bonus)* **Les mesures** : rejouer une ancienne trame de poids pour masquer un vol (la ruche semble toujours pleine), ou envoyer une fausse position GPS (UC-CY02).
5. *(bonus)* **Le login / mot de passe** : se connecter à la place d'un coordinateur pour valider de fausses récoltes.

---

## Attributs sensibles (en rouge dans le MCD)

- APICULTRICE : `telephone`
- RUCHE : `latitude`, `longitude`
- MESURE : `latitude`, `longitude` (position reçue)
- UTILISATEUR : `login`, `mot_de_passe_hash`
- RÉCOLTE : `quantite_kg` (le lien VALIDE, qui a validé, est sensible lui aussi, mais une association sans attribut n'a rien à colorer)
- INSPECTION : `photo` (peut révéler le lieu ou des personnes)

---

## Question 6 · Sensibilité et menaces (STRIDE)

Légende : **S** usurper une identité · **T** altérer · **R** nier avoir agi · **I** divulguer · **D** rendre indisponible · **E** obtenir plus de droits

| Entité | Sensibilité | Qui lit | Qui modifie | Menace STRIDE et ce que gagne l'attaquant |
|---|---|---|---|---|
| SITE | interne | tous les rôles | gestionnaire, admin | **T** : modifier le pays ou le nom d'un site pour fausser les statistiques par pays et les rapports bailleurs |
| COOPÉRATIVE | interne | coordinateur, gestionnaire, admin | gestionnaire, admin | **T** : ajouter de fausses adhésions pour gonfler l'indicateur « coopératives actives » présenté aux bailleurs |
| APICULTRICE | confidentielle (téléphone = donnée personnelle de bénéficiaire vulnérable) | l'apicultrice elle-même, coordinateur de son site, gestionnaire, admin | gestionnaire, admin | **I** : récupérer les téléphones pour de l'hameçonnage ou du démarchage |
| RUCHE | confidentielle (position GPS de référence) | l'apicultrice propriétaire, coordinateur du site, gestionnaire, admin | coordinateur, admin (l'apicultrice déclare ses transhumances dans la future entité TRANSHUMANCE, sans modifier la ruche) | **I** : connaître la position GPS pour voler la ruche · **T** : modifier la position de référence pour qu'un vol ne déclenche pas d'alerte |
| MESURE | interne (confidentielle pour la position) | l'apicultrice propriétaire, coordinateur du site, gestionnaire | les capteurs uniquement (personne ne modifie à la main) | **T** : **rejouer une ancienne mesure** de poids pour cacher un vol ou une récolte non déclarée (UC-CY02) · **S** : un faux capteur envoie des trames au nom d'une ruche · **D** : saturer la base de fausses mesures |
| INSPECTION | interne | l'apicultrice, coordinateur du site, gestionnaire | l'apicultrice qui a réalisé l'inspection | **R** : une apicultrice nie avoir constaté l'absence de la reine · **T** : antidater une inspection saisie hors ligne |
| RÉCOLTE | critique (production, revenus) | l'apicultrice, coordinateur du site, gestionnaire | l'apicultrice déclare ; le coordinateur valide | **R** : **une récolte validée sans qu'on sache par qui** : personne n'est responsable de la validation · **T** : gonfler une quantité déclarée |
| ALERTE | interne | l'apicultrice concernée, coordinateur du site, gestionnaire, admin | le système crée ; le coordinateur traite et ferme | **T** : fermer ou supprimer les alertes « vol » pour que le vol passe inaperçu · **T** : baisser le niveau de confiance · **D** : noyer les coordinateurs sous de fausses alertes (fatigue d'alerte) pour que la vraie passe inaperçue |
| UTILISATEUR | critique | admin (l'utilisateur voit son propre compte) | admin | **S** : se connecter à la place d'un coordinateur (d'où MFA et blocage après 5 tentatives, UC-T01) · **E** : se donner le rôle admin · **R** : **effacer l'historique des actions** pour nier avoir agi (le CDC exige une traçabilité complète, § 7.2) |

Lettres utilisées : **S, T, R, I, D, E** (les 6).

Principe appliqué : **moindre privilège** (RBAC 4 rôles, CDC § 8.2) : chacun n'accède qu'à ce dont il a besoin (une apicultrice ne voit que ses ruches, un coordinateur que son site).

---

## Testez-vous · Lab 1

1. La date d'adhésion appartient **au lien** entre l'apicultrice et la coopérative (association ADHÈRE).
2. Le nom est un mauvais identifiant car **deux personnes peuvent porter le même nom** (deux « Aminata Diop »), et un nom peut changer.
3. Le rejeu d'une ancienne mesure de poids correspond à **T** (altération / falsification des données).
4. « Une ruche appartient à une seule apicultrice » : **1,1 du côté de RUCHE**.

---

## Schéma relationnel

Lab 2, étape 2.1.

Notation : clé primaire en premier, `#` = clé étrangère.

| Table | Clé primaire | Autres colonnes | Clés étrangères (vers quelle table) |
|---|---|---|---|
| site | id (code lisible `SN-CASA`) | nom, pays | — |
| cooperative | id (UUID) | nom | #site_id → site |
| apicultrice | id (UUID) | nom, telephone (UNIQUE) ; (id, site_id) UNIQUE | #site_id → site |
| ruche | id (UUID) | code (UNIQUE), latitude, longitude, date_installation | #site_id → site, #(apicultrice_id, site_id) → apicultrice (id, site_id) (clé composée) |
| adhesion | (apicultrice_id, cooperative_id) | date_adhesion | #apicultrice_id → apicultrice, #cooperative_id → cooperative |
| utilisateur | id (UUID) | login, mot_de_passe_hash, role | #site_id → site, #apicultrice_id → apicultrice (UNIQUE) |
| mesure | id (bigint, jamais exposé) | horodatage, poids_kg, temp_int_c, temp_ext_c, humidite_pct, activite_sonore, batterie_pct, latitude, longitude | #ruche_id → ruche |
| inspection | id (UUID) | date_inspection, etat_colonie, reine_presente, observations, photo | #ruche_id → ruche, #apicultrice_id → apicultrice |
| recolte | id (UUID) | date_recolte, quantite_kg, statut, date_validation | #ruche_id → ruche, #validee_par → utilisateur |
| alerte | id (UUID) | type, date_alerte, niveau_confiance, statut | #ruche_id → ruche |

**10 tables, 14 clés étrangères.** Décompte : les 12 associations binaires qui ne sont pas n,n donnent chacune 1 clé étrangère (12), et ADHÈRE devient la table `adhesion` avec 2 clés étrangères, soit 12 + 2 = **14**. La colonne `utilisateur.site_id` vient de EST AFFECTÉ.

Vérification dans PostgreSQL (TP, étape 2.4), après `schema.sql` :

```sql
SELECT conrelid::regclass, confrelid::regclass, conname
FROM pg_constraint WHERE contype = 'f' ORDER BY 1, 2;
```

```
  conrelid   |  confrelid  |          conname           
-------------+-------------+----------------------------
 cooperative | site        | cooperative_site_fk
 apicultrice | site        | apicultrice_site_fk
 ruche       | site        | ruche_site_fk
 ruche       | apicultrice | ruche_apicultrice_fk
 adhesion    | cooperative | adhesion_cooperative_fk
 adhesion    | apicultrice | adhesion_apicultrice_fk
 utilisateur | site        | utilisateur_site_fk
 utilisateur | apicultrice | utilisateur_apicultrice_fk
 mesure      | ruche       | mesure_ruche_fk
 inspection  | apicultrice | inspection_apicultrice_fk
 inspection  | ruche       | inspection_ruche_fk
 recolte     | ruche       | recolte_ruche_fk
 recolte     | utilisateur | recolte_validee_par_fk
 alerte      | ruche       | alerte_ruche_fk
(14 rows)
```

Règles appliquées :
1. **Une entité devient une table** : 9 entités → 9 tables.
2. **Un lien (0,1 ou 1,1) – (0,n) devient une clé étrangère du côté x,1** : `NOT NULL` si 1,1 (ruche → site, ruche → apicultrice, mesure → ruche, etc.), `NULL` autorisé si 0,1 (VALIDE donne `recolte.validee_par`, vide tant que la récolte n'est que déclarée ; EST AFFECTÉ donne `utilisateur.site_id`).
3. **Un lien n,n devient une table** : ADHÈRE devient `adhesion`, clé primaire sur les deux clés étrangères, avec `date_adhesion`. Le minimum 1 côté apicultrice (1,n : toute apicultrice adhère à au moins une coopérative) n'est pas garanti par le MLD : il faudrait un déclencheur différé.
4. **Un lien 0,1 – 0,1 devient une clé étrangère UNIQUE** : `utilisateur.apicultrice_id UNIQUE`, une apicultrice n'a jamais deux comptes.

Choix des clés :
- **Code lisible** pour le site : court, stable, pas secret.
- **UUID** pour tout ce qu'une application exposera (ruche, apicultrice, récolte…) : `/ruches/42` laisse deviner `/ruches/43`, pas un UUID.
- **bigint** pour la mesure : très gros volume, jamais exposée seule.

Contraintes de sécurité posées :
- `mesure_anti_rejeu UNIQUE (ruche_id, horodatage)` : une trame rejouée **à l'identique** est refusée (UC-CY02). C'est une première barrière : un vrai anti-rejeu demande aussi un compteur et une signature du capteur (voir les limites dans tests_schema.sql).
- `CHECK` sur les plages physiques des mesures : une trame absurde est refusée.
- `recolte_quantite_positive` et `recolte_validation_tracee` : pas de quantité négative, pas de récolte « validée » sans validateur ni date (menace R).
- `alerte_confiance_bornee CHECK (niveau_confiance BETWEEN 0 AND 1)`.
- Sur `utilisateur` : un compte « apicultrice » est forcément relié à une apicultrice, et un coordinateur forcément à un site (moindre privilège).
- Ajoutées après le retour de la prof (RENDU.md, section 7) : `mot_de_passe_hash` obligatoire au format bcrypt (`utilisateur_hache_bcrypt`) ; la ruche sur le site de son apicultrice (clé composée `ruche_apicultrice_fk`) ; pas d'inspection avant 2020 (`inspection_date_plausible`) ni dans le futur (trigger `inspection_pas_dans_le_futur`) ; un index pour chaque clé étrangère qui n'est pas déjà en tête d'une clé primaire ou d'un UNIQUE.
