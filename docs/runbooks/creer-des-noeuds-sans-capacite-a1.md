# Créer des nœuds A1 sans capacité disponible

À utiliser quand `terraform apply` échoue sur une instance avec :

```
Error: 500-InternalError, Out of host capacity.
```

Les instances Ampere A1 de l'offre gratuite sont très demandées. La région manque alors de machines physiques pour la forme demandée. Ce n'est ni une erreur de configuration ni un dépassement de quota, et la capacité revient par vagues, souvent la nuit ou en début de semaine.

## Ce qui ne sert à rien

- Changer de domaine de panne ou laisser Oracle le choisir : le manque de capacité concerne tout le domaine de disponibilité. Testé le 2026-11-21.
- Relancer en boucle rapprochée : chaque tentative est un appel d'API, et la capacité ne revient pas en quelques secondes.

## Procédure

Depuis `terraform/envs/prod`, initialisé :

```bash
../../../scripts/apply-until-capacity.sh 30 600
```

Le script retente toutes les 10 minutes, 30 fois au plus. Il s'arrête dès que les instances sont créées, et refuse d'appliquer un plan qui contiendrait autre chose que des créations d'instances.

Lancé en arrière-plan, sa sortie peut être suivie avec :

```bash
nohup ../../../scripts/apply-until-capacity.sh 30 600 > /tmp/capacite.log 2>&1 &
tail -f /tmp/capacite.log
```

## Si une seule instance est créée

Le script continue pour l'instance manquante. Rien n'est à défaire : Terraform ne garde dans le state que les instances réellement créées.

## Si la capacité ne revient pas

Après plusieurs jours sans succès, les options sont, dans l'ordre :

1. une seule instance de 2 OCPU et 12 Go, plan de contrôle et nœud de travail confondus (scénario prévu par l'ADR 0003) ;
2. le passage de la tenancy en paiement à l'usage, réputé prioritaire pour la capacité. C'est ce qui a été fait le 2026-11-21, sous quotas : voir l'[ADR 0008](../adr/0008-passer-en-paiement-a-l-usage-sous-quotas.md).

## Historique

| Date | Tentatives | Issue |
| --- | --- | --- |
| 2026-11-20 au 2026-11-21 | 12 échecs sur une nuit puis une matinée | Créés le 2026-11-21 à 10h24 (UTC), 30 minutes après la demande de passage en paiement à l'usage |
