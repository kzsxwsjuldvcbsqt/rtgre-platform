# 0023. Redémarrer les nœuds seuls, la nuit

- Statut : accepté
- Date : 2026-11-22

## Contexte

Les mises à jour de sécurité s'installent seules sur les nœuds. Certaines, comme un nouveau noyau, ne s'appliquent qu'au redémarrage. Il était désactivé : au lendemain de leur création, les deux nœuds attendaient déjà un redémarrage, et rien ne le signalait.

La plateforme a un seul exploitant, et un seul nœud de travail : le redémarrer coupe le site.

## Options envisagées

### Redémarrer à la main

Le moment est choisi, et quelqu'un regarde. Mais personne ne le fera chaque semaine : les correctifs attendraient.

### kured

Un pod par nœud surveille le marqueur de redémarrage, vide le nœud, le redémarre, et ne laisse passer qu'un nœud à la fois. Vider le seul nœud de travail ne déplace rien : ses pods n'ont nulle part où aller. C'est un composant privilégié de plus, et une image de plus à suivre.

### Le redémarrage d'unattended-upgrades

L'outil qui installe les mises à jour sait redémarrer à une heure donnée. Rien à déployer. Il ne vide pas le nœud et ne connaît pas les autres nœuds.

## Décision

Chaque nœud redémarre seul, la nuit qui suit une mise à jour qui l'exige, à une heure qui lui est propre.

- **Le plan de contrôle à 3 h 10, le nœud de travail à 3 h 40**, heure UTC des nœuds : jamais les deux à la fois. C'est entre 4 h et 6 h à Paris, hors de la génération horaire et de la conservation des journaux du lundi.
- **Sans vider le nœud** : avec un seul nœud de travail, cela ne protégerait rien.
- **Une métrique dit qu'un nœud attend**, `node_reboot_required`, écrite par une minuterie du rôle `hardening` pour node-exporter. L'alerte `NoeudAttendUnRedemarrage` part si cela dure plus d'un jour et demi : le redémarrage de la nuit n'a alors pas eu lieu.

## Conséquences

- Mesuré le 22 novembre 2026, en redémarrant les deux nœuds à la main, visiteurs renvoyés sur GitHub Pages :
  - **nœud de travail** : le site est coupé 3 minutes, dont 30 secondes de démarrage du système ; le reste est le retour des pods, du réseau au serveur web. Tout revient seul : volumes, certificats, contrôle des images, 28 cibles sur 28.
  - **plan de contrôle** : le site ne voit rien, aucune requête perdue sur 213. L'API de Kubernetes manque 88 secondes.
- **Les nuits où une mise à jour l'exige, le site est donc coupé trois minutes**, vers 4 h 40 ou 5 h 40 à Paris. C'est sous le seuil de l'alerte `SiteInjoignable`, cinq minutes. La sonde extérieure, qui passe tous les quarts d'heure, peut tomber dessus : elle ouvrirait un incident, refermé à la sonde suivante.
- Si un nœud ne revient pas de son redémarrage, le nœud de travail emporte les alertes du cluster : c'est la sonde extérieure qui le signale ([ADR 0022](0022-surveiller-le-site-depuis-github-actions.md)).
- Les pods sont arrêtés par l'extinction du système, pas par Kubernetes. Prometheus et Loki ont repris sans perte visible.
- Le redémarrage a été joué à la main. Son déclenchement par la passe des mises à jour ne s'observera qu'à la prochaine qui l'exigera.
- Avec un second nœud de travail, cette décision serait à revoir : vider le nœud aurait alors un sens.
