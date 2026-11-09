# rejouer_tout.ps1 : assemble et teste les 4 livrables du jour (TP Jour 1, section 6)
# Groupe : Praveen, Ugo, Hugo, Corentin
#
# Rejoue TOUTE la journée, dans l'ordre des labs, sur la base queenbee, puis
# lance verif_rendu.sql qui compare chaque résultat à l'attendu du TP.
#
# ATTENTION : schema.sql supprime et recrée les tables : la base queenbee
# repart de zéro (c'est voulu : on prouve que tout se reconstruit).
#
# Lancement, depuis dossier-bdd, dans PowerShell : définir d'abord dans le
# terminal les trois variables de connexion de l'étape 3.2 du TP (utilisateur,
# mot de passe, hôte), puis :
#   powershell -ExecutionPolicy Bypass -File .\rejouer_tout.ps1
# Le mot de passe vient du terminal, jamais de ce fichier (comme au lab 3).
# Options : -Base autre_base   -Utilisateur autre_role

param(
    [string]$Base = "queenbee",
    [string]$Utilisateur = "postgres"
)

Set-Location $PSScriptRoot
# Les fichiers .sql sont en UTF-8 : sans cela, psql sous Windows les lit en
# WIN1252 et « Sénégal » ne passe plus le CHECK de la table site.
$env:PGCLIENTENCODING = "UTF8"
$env:PGDATABASE = $Base
if (-not $env:PGUSER) { $env:PGUSER = $Utilisateur }

# psql : dans le Path, sinon dans le dossier d'installation de PostgreSQL
$psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
if (-not $psql) {
    $psql = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin\psql.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName | Select-Object -Last 1 -ExpandProperty FullName
}
if (-not $psql) { Write-Host "psql introuvable (voir étape 0.3 du TP)" -ForegroundColor Red; exit 1 }

$etape = 0
function Lancer([string]$fichier, [string]$titre, [switch]$Stop, [switch]$EchecAttendu) {
    $script:etape++
    Write-Host ""
    Write-Host ("=== {0,2}. {1} ({2})" -f $script:etape, $titre, (Split-Path $fichier -Leaf)) -ForegroundColor Cyan
    $arguments = @("-X", "-U", $Utilisateur, "-d", $Base, "-f", $fichier)
    if ($Stop) { $arguments += @("-v", "ON_ERROR_STOP=1") }
    & $psql @arguments
    $code = $LASTEXITCODE
    if ($EchecAttendu) {
        if ($code -eq 0) { Write-Host "ÉCHEC : ce fichier aurait dû être refusé" -ForegroundColor Red; exit 1 }
        Write-Host "-> refus attendu, obtenu (code $code)" -ForegroundColor Green
    } elseif ($code -ne 0) {
        Write-Host "ÉCHEC : psql a renvoyé le code $code" -ForegroundColor Red; exit 1
    }
}

# anomalies.sql se lance en trois morceaux : la migration doit passer entre
# eux (voir son en-tête). On coupe aux lignes « -- Ici, dans le terminal ».
$utf8 = New-Object System.Text.UTF8Encoding($false)
$lignes = [System.IO.File]::ReadAllLines((Join-Path $PSScriptRoot "anomalies.sql"), $utf8)
$coupes = @(0..($lignes.Count - 1) | Where-Object { $lignes[$_] -like "-- Ici, dans le terminal*" })
if ($coupes.Count -ne 2) { Write-Host "anomalies.sql : 2 repères « -- Ici, dans le terminal » attendus" -ForegroundColor Red; exit 1 }
$morceaux = @(
    $lignes[0..($coupes[0] - 1)],
    $lignes[$coupes[0]..($coupes[1] - 1)],
    $lignes[$coupes[1]..($lignes.Count - 1)]
)
$anomalies = @()
for ($i = 0; $i -lt 3; $i++) {
    $chemin = Join-Path $env:TEMP ("queenbee_anomalies_{0}.sql" -f ($i + 1))
    [System.IO.File]::WriteAllLines($chemin, [string[]]$morceaux[$i], $utf8)
    $anomalies += $chemin
}

# --- Lab 2 · schéma relationnel ---------------------------------------------
Lancer "schema.sql"        "Lab 2 : création des 10 tables" -Stop
Lancer "donnees.sql"       "Lab 2 : jeu d'essai" -Stop
Lancer "tests_schema.sql"  "Lab 2 : essayer de casser la base (ERROR attendues : tests 1, 2, 3, 6, 8)"
# --- Lab 3 · requêtes ---------------------------------------------------------
Lancer "requetes.sql"      "Lab 3 : les cinq questions" -Stop
# --- Lab 4 · dépendances fonctionnelles ----------------------------------------
Lancer "plat.sql"          "Lab 4 : table à plat" -Stop
Lancer "contraintes.sql"   "Lab 4 : DF et logins uniques (ERROR attendues : commandes 2 et 6)"
# --- Lab 5 · formes normales ---------------------------------------------------
Lancer "plat.sql"          "Lab 5 : extrait propre" -Stop
Lancer $anomalies[0]       "Lab 5.1 : anomalies (ERROR attendue : insertion d'un site sans ruche)"
Lancer "migration_3nf.sql" "Lab 5.2 : migration sur données corrompues" -Stop -EchecAttendu
Lancer $anomalies[1]       "Lab 5.2 : nettoyage" -Stop
Lancer "migration_3nf.sql" "Lab 5.2 : migration après nettoyage" -Stop
Lancer $anomalies[2]       "Lab 5.3 : preuve sans perte (ERROR attendue : second pays pour SN-KOLD)"

# --- Lab 3 · les programmes Python (si Python et psycopg sont installés) ------
# Le test de requêtes empilées (DROP TABLE alerte) n'est PAS rejoué ici :
# il détruirait la base avant le contrôle final.
$python = $null
$candidats = @("python", "py") +
    @(Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe" -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty FullName)
foreach ($candidat in $candidats) {
    if (Get-Command $candidat -ErrorAction SilentlyContinue) {
        & $candidat -c "import psycopg" 2>$null
        if ($LASTEXITCODE -eq 0) { $python = $candidat; break }
    }
}
if ($python) {
    # Sans cela, PowerShell peut ajouter un BOM invisible devant la saisie envoyée
    # par le tube, et le code SN-CASA-014 n'est plus reconnu.
    $sansBom = New-Object System.Text.UTF8Encoding($false)
    $OutputEncoding = $sansBom
    try { [Console]::InputEncoding = $sansBom } catch { }
    $env:PYTHONIOENCODING = "utf-8"
    Write-Host ""
    Write-Host "=== Lab 3 : injection SQL (query_vuln.py vulnérable, query.py corrigé)" -ForegroundColor Cyan
    $saisies = @("SN-CASA-014", "' OR '1'='1", "' UNION SELECT nom, telephone FROM apicultrice --")
    $attendusVuln = @(1, 11, 8)    # l'injection passe : toutes les ruches, puis les téléphones
    $attendusQuery = @(1, 0, 0)    # la requête paramétrée résiste
    for ($i = 0; $i -lt 3; $i++) {
        $vuln = @($saisies[$i] | & $python query_vuln.py | Where-Object { "$_".StartsWith("(") }).Count
        $sortie = $saisies[$i] | & $python query.py
        $nb = [int](($sortie | Select-String "ligne\(s\)" | Select-Object -First 1).ToString().Split(" ")[-2])
        $etat = if ($vuln -eq $attendusVuln[$i] -and $nb -eq $attendusQuery[$i]) { "OK" } else { "KO" }
        Write-Host ("  {0,-50} query_vuln.py : {1,2} ligne(s) | query.py : {2} ligne(s) [{3}]" -f $saisies[$i], $vuln, $nb, $etat)
        if ($etat -eq "KO") { exit 1 }
    }
} else {
    Write-Host ""
    Write-Host "Python + psycopg absents : test de query.py ignoré (étape 0.3 du TP)." -ForegroundColor Yellow
}

# --- Contrôle final -----------------------------------------------------------
Lancer "verif_rendu.sql"   "Section 6 : contrôle des 4 livrables" -Stop

Remove-Item $anomalies -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Tout est rejoué et vérifié : les 4 livrables sont prêts." -ForegroundColor Green
