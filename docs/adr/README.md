# Décisions d'architecture

Chaque fichier consigne une décision, son contexte et ses conséquences. La méthode est décrite dans [0001](0001-consigner-les-decisions-d-architecture.md) et le modèle dans [template.md](template.md).

| N° | Décision | Statut |
| --- | --- | --- |
| [0001](0001-consigner-les-decisions-d-architecture.md) | Consigner les décisions d'architecture | accepté |
| [0002](0002-heberger-sur-oracle-cloud-always-free.md) | Héberger sur Oracle Cloud Always Free | accepté |
| [0003](0003-monter-kubernetes-avec-kubeadm.md) | Monter Kubernetes avec kubeadm | accepté |
| [0004](0004-stocker-le-state-avec-le-backend-oci.md) | Stocker le state avec le backend oci natif | accepté |
| [0005](0005-authentifier-la-ci-par-federation-d-identite.md) | Authentifier la CI par fédération d'identité | accepté |
| [0006](0006-sortir-par-la-passerelle-internet-sans-nat.md) | Sortir par la passerelle Internet, sans NAT | accepté |
| [0007](0007-appliquer-la-prod-depuis-la-ci-apres-approbation.md) | Appliquer la prod depuis la CI, après approbation | accepté |
| [0008](0008-passer-en-paiement-a-l-usage-sous-quotas.md) | Passer en paiement à l'usage, sous quotas | accepté |
| [0009](0009-reseau-des-pods-avec-cilium.md) | Réseau des pods avec Cilium, sur Kubernetes 1.36 | accepté |
| [0010](0010-deployer-en-gitops-avec-argo-cd.md) | Déployer en GitOps avec Argo CD | accepté |
| [0011](0011-stocker-sur-des-volumes-locaux-statiques.md) | Stocker sur des volumes locaux statiques | accepté |
| [0012](0012-exposer-par-un-network-load-balancer-et-gateway-api.md) | Exposer par un Network Load Balancer et Gateway API | accepté |
| [0013](0013-certificats-par-cert-manager-et-lets-encrypt.md) | Certificats par cert-manager et Let's Encrypt | accepté |
| [0014](0014-journaux-de-visite-sans-adresse-complete.md) | Journaux de visite sans adresse complète | accepté |
| [0015](0015-metriques-avec-prometheus-et-son-operateur.md) | Métriques avec Prometheus et son opérateur | accepté |
| [0016](0016-grafana-en-lecture-seule-sans-compte.md) | Grafana en lecture seule, sans compte | accepté |
| [0017](0017-journaux-avec-loki-et-alloy.md) | Journaux avec Loki et Alloy | accepté |
| [0018](0018-alertes-avec-alertmanager-et-telegram.md) | Alertes avec Alertmanager et Telegram | accepté ; canal remplacé par [0021](0021-envoyer-les-alertes-par-courrier.md) |
| [0019](0019-controler-les-images-a-l-admission-avec-kyverno.md) | Contrôler les images à l'admission avec Kyverno | accepté |
| [0020](0020-chiffrer-le-state-avec-une-cle-du-vault.md) | Chiffrer le state avec une clé du Vault | accepté |
| [0021](0021-envoyer-les-alertes-par-courrier.md) | Envoyer les alertes par courrier | accepté |
| [0022](0022-surveiller-le-site-depuis-github-actions.md) | Surveiller le site depuis GitHub Actions | accepté ; complété par [0024](0024-surveiller-le-load-balancer-par-une-alarme-d-oracle.md) et [0027](0027-lancer-la-sonde-exterieure-par-un-minuteur.md) |
| [0023](0023-redemarrer-les-noeuds-seuls-la-nuit.md) | Redémarrer les nœuds seuls, la nuit | accepté |
| [0024](0024-surveiller-le-load-balancer-par-une-alarme-d-oracle.md) | Surveiller le load balancer par une alarme d'Oracle | accepté |
| [0025](0025-mesurer-l-audience-avec-umami.md) | Mesurer l'audience avec Umami | accepté |
| [0026](0026-sauvegarder-la-base-d-umami-avec-l-identite-des-noeuds.md) | Sauvegarder la base d'Umami avec l'identité des nœuds | accepté |
| [0027](0027-lancer-la-sonde-exterieure-par-un-minuteur.md) | Lancer la sonde extérieure par un minuteur | accepté |
| [0028](0028-mettre-en-ligne-l-image-du-site-par-un-workflow-declenche.md) | Mettre en ligne l'image du site par un workflow déclenché | accepté |
