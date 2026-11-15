# FPS Boost — RTX 3060 / Ryzen 7 5800X / MSI B550 Gaming Edge WiFi

Scripts Windows 10/11 pour gagner des fps et réduire la latence. Tout est
**réversible** : chaque valeur d'origine est sauvegardée avant modification.

## Utilisation

1. Télécharge le dossier `pc-optimisation` et décompresse-le (par ex. sur le Bureau).
2. Double-clic sur **`LANCER.bat`** et accepte la demande administrateur.
3. Tape `0` : le diagnostic crée `FPSBoost_Diagnostic.txt` sur ton Bureau.
4. Tape `A` pour tout appliquer, puis **redémarre**.
5. Fais les réglages de `GUIDE_NVIDIA_ET_BIOS.md`.

Pour tout annuler : `LANCER.bat` puis `R`.

## Ce que fait chaque script

| Script | Effet | Gain attendu |
|---|---|---|
| `00_Diagnostic.ps1` | Lecture seule. Détecte XMP inactif, écran à 60 Hz, single channel, GPU en mauvais slot, etc. | Trouve les vrais freins |
| `01_Windows_Gaming.ps1` | Mode alimentation Performances optimales, Mode Jeu, Game DVR coupé, HAGS, accélération souris coupée, priorité au jeu. Option : intégrité mémoire. | Fps mini plus stables, moins de délai |
| `02_Nettoyage.ps1` | Temporaires, télémétrie, applis en arrière-plan. Option : caches de shaders. | Moins de saccades |
| `03_Reseau_Latence.ps1` | Nagle coupé, économies d'énergie carte réseau coupées, modération d'interruptions coupée. | Délai réseau, pas les fps |
| `99_Restaurer.ps1` | Remet chaque réglage à sa valeur d'origine. | — |

Sauvegarde : `C:\ProgramData\FPSBoost\backup.json`.

## Ce qui rapporte vraiment, par ordre d'importance

1. **A-XMP activé dans le BIOS** (RAM à sa vraie fréquence)
2. **Réglages graphiques du jeu** (ombres, effets, distance d'affichage en bas)
3. **PBO + Curve Optimizer** dans le BIOS
4. **NVIDIA Reflex + mode latence faible**
5. Les scripts Windows de ce dossier
6. Resizable BAR

## À savoir

- Les scripts n'ont pas pu être exécutés sur une machine Windows avant livraison :
  si une ligne s'affiche en jaune `[!!]`, copie le message.
- Aucun script ne peut faire dépasser à une RTX 3060 ce qu'elle peut calculer. 200 fps
  et plus est réaliste en 1080p sur Valorant, CS2, Fortnite (mode Performance),
  Rocket League, R6. Sur Warzone, Cyberpunk ou les AAA récents, la carte plafonne
  bien avant, quel que soit le réglage.
- Rien ici ne désactive Windows Defender, les mises à jour, ni les protections
  Spectre/Meltdown : le gain est négligeable et le risque réel.
