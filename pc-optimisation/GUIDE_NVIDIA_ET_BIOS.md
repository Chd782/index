# Réglages manuels : NVIDIA puis BIOS

Ces réglages ne peuvent pas être faits proprement par script. Ce sont pourtant ceux
qui rapportent le plus sur ta config (5800X + RTX 3060 + MSI B550 Gaming Edge WiFi).

## 1. Panneau de configuration NVIDIA

Pilote d'abord : installe le dernier pilote Game Ready (installation propre cochée).

`Gérer les paramètres 3D` > onglet `Paramètres globaux` :

| Réglage | Valeur |
|---|---|
| Mode de gestion de l'alimentation | Privilégier les performances maximales |
| Mode latence faible | Ultra (ou Activé si le jeu a NVIDIA Reflex) |
| Filtrage des textures – Qualité | Hautes performances |
| Optimisation threadée | Activé |
| Taille du cache de shaders | Illimitée |
| Synchronisation verticale | Désactivé |
| Fréquence d'images max. | Désactivé (ou 3 fps sous ton Hz si G-Sync) |

Dans chaque jeu compétitif qui le propose : **NVIDIA Reflex = Activé + Boost**. C'est
le réglage qui réduit le plus le délai entre ton clic et l'image.

`Modifier la résolution` : vérifie que la fréquence est au maximum de ton écran
(144 / 165 / 240 Hz), pas 60 Hz.

## 2. BIOS MSI B550 Gaming Edge WiFi (Click BIOS 5)

Fais-les **dans cet ordre, un par un**, en testant entre chaque. Touche `Suppr` au
démarrage, puis `F7` pour le mode avancé. Les noms de menu peuvent varier un peu
selon la version du BIOS.

### Étape 0 — Mettre à jour le BIOS
Télécharge le dernier BIOS sur la page support MSI de ta carte, mets-le sur une clé
USB en FAT32, puis `M-FLASH` dans le BIOS. Ne coupe jamais le courant pendant le
flash. Les versions récentes corrigent les micro-saccades fTPM et stabilisent PBO.

### Étape 1 — A-XMP (le plus gros gain)
`OC` > `A-XMP` > `Profile 1` (parfois `Profile 2`).
Sans ça, ta RAM tourne à 2133/2400 MHz au lieu de 3200/3600 MHz. Sur un Ryzen 5000,
c'est souvent +15 à 30 % de fps minimum. Le diagnostic (option 0) te dit si c'est
déjà actif.
Vérifie aussi que tes 2 barrettes sont dans les slots **A2 et B2** (2ᵉ et 4ᵉ en
partant du processeur).

### Étape 2 — Resizable BAR
`Settings` > `Advanced` > `PCIe/PCI Sub-system Settings` :
- `Above 4G memory/Crypto Currency mining` = Enabled
- `Re-Size BAR Support` = Enabled

Nécessite le mode UEFI (`Settings` > `Advanced` > `Windows OS Configuration` >
`BIOS CSM/UEFI Mode` = UEFI). **Attention** : si ton Windows est installé en mode
Legacy/MBR, passer en UEFI l'empêchera de démarrer. Vérifie avant : `Win+R` >
`msinfo32` > ligne « Mode BIOS » doit afficher « UEFI ».

### Étape 3 — PBO + Curve Optimizer (gain CPU gratuit)
`OC` > `Advanced CPU Configuration` > `AMD Overclocking` > `Precision Boost Overdrive` :
- `Precision Boost Overdrive` = Advanced
- `PBO Limits` = Motherboard
- `Curve Optimizer` = All Cores, `Sign` = Negative, `Magnitude` = **10** pour commencer
- `Max CPU Boost Clock Override` = 0 MHz au début

Teste (jeux + un test de stabilité type OCCT ou Cinebench en boucle 20 min). Si
c'est stable, monte à 15 puis 20. Si le PC plante ou redémarre au repos, redescends
de 5. Laisse `Game Boost` **désactivé** : PBO fait mieux.

Le 5800X chauffe beaucoup : au-delà de 85 °C en jeu, il perd des fps. Un bon
ventirad ou un AIO 240 mm et une pâte thermique fraîche comptent autant que le
réglage.

### Étape 4 — À laisser tels quels
- `Global C-State Control`, `CPPC`, `CPPC Preferred Cores` = Enabled / Auto
  (nécessaires pour que le boost monocœur fonctionne)
- `Secure Boot` et `fTPM` : ne pas désactiver (Valorant, Fortnite et d'autres
  anti-triche les exigent sous Windows 11)

### En cas de problème
Si le PC ne démarre plus après un réglage : bouton/cavalier `Clear CMOS` (JBAT1) ou
retire la pile 30 secondes. Tout revient par défaut, rien n'est cassé.
