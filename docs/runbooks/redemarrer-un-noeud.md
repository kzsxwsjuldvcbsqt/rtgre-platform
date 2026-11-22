# Redémarrer un nœud

Un nœud redémarre seul, la nuit, quand une mise à jour de sécurité l'exige ([ADR 0023](../adr/0023-redemarrer-les-noeuds-seuls-la-nuit.md)) : `cp-1` à 3 h 10 UTC, `wk-1` à 3 h 40. Les commandes passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

| Nœud | Ce que voit un visiteur | Durée mesurée |
| --- | --- | --- |
| `wk-1` | Le site ne répond plus | 3 minutes |
| `cp-1` | Rien. L'API de Kubernetes manque : pas de génération ni de déploiement pendant ce temps | 1 minute 30 |

## Voir si un nœud attend un redémarrage

Dans Prometheus, `node_reboot_required` vaut 1. Sur le nœud :

```bash
ssh -F ansible/.ssh/bastion.conf wk-1 "cat /var/run/reboot-required.pkgs; sudo shutdown --show"
```

La première commande liste les paquets qui l'exigent, la seconde dit si un redémarrage est déjà programmé. Il l'est par la passe quotidienne des mises à jour, entre 6 h et 7 h UTC, pour la nuit suivante.

## Annuler un redémarrage programmé

```bash
ssh -F ansible/.ssh/bastion.conf wk-1 sudo shutdown -c
```

La passe du lendemain le reprogrammera. Pour suspendre durablement, passer `hardening_unattended_upgrades_automatic_reboot` à `false` dans l'inventaire, et rejouer le playbook.

## Redémarrer à la main

Pour ne pas attendre la nuit, ou après une intervention. Redémarrer `wk-1` coupe le site trois minutes : en journée, renvoyer d'abord les visiteurs sur GitHub Pages et attendre cinq minutes ([basculer-rtgre-fr](basculer-rtgre-fr.md)). Le nom `test.rtgre.fr` désigne toujours le cluster : il sert à suivre son retour.

```bash
ssh -F ansible/.ssh/bastion.conf wk-1 sudo systemctl reboot
```

Puis, une fois le nœud revenu :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl get nodes
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl get pods -A | grep -v -e Running -e Completed"
curl -s -o /dev/null -w '%{http_code}\n' https://test.rtgre.fr/
```

Les deux nœuds sont `Ready`, aucun pod ne reste en attente, le site répond 200. Redémarrer ensuite `cp-1` de la même façon, jamais en même temps. Ramener enfin les visiteurs vers le cluster.

## L'alerte NoeudAttendUnRedemarrage

Le nœud attend depuis plus d'un jour et demi : le redémarrage de la nuit n'a pas eu lieu.

```bash
ssh -F ansible/.ssh/bastion.conf wk-1 "grep -i reboot /etc/apt/apt.conf.d/52unattended-upgrades-hardening; systemctl list-timers apt-daily-upgrade.timer --no-pager; sudo tail -n 20 /var/log/unattended-upgrades/unattended-upgrades.log"
```

| Constat | Cause | Que faire |
| --- | --- | --- |
| `Automatic-Reboot "false"` | Le redémarrage automatique a été désactivé dans l'inventaire. | Le réactiver, ou redémarrer à la main. |
| La minuterie n'a pas tourné depuis plus d'un jour | La passe quotidienne est arrêtée. | `sudo systemctl start apt-daily-upgrade.timer` |
| Le journal montre une erreur de paquet | Une mise à jour est restée à moitié installée. | `sudo dpkg --configure -a`, puis relancer `sudo unattended-upgrade`. |
| Tout semble en ordre | Le redémarrage a été annulé à la main. | Redémarrer à la main. |

## Le nœud ne revient pas

Après cinq minutes sans réponse en SSH : console d'Oracle, instance du nœud, « Console connection » pour lire l'écran de démarrage, puis « Reboot » ou « Reset ». Si c'est `wk-1`, le site est coupé : [site-injoignable](site-injoignable.md).
