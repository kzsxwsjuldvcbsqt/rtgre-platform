# Zone rtgre.fr, chez OVH. Ce fichier ne contient aucun secret et il est suivi par Git.
ovh_endpoint = "ovh-eu"
zone         = "rtgre.fr"

# Une durée de vie de 0 désigne celle de la zone, 3600 secondes : c'est ce que portent les
# enregistrements créés depuis l'espace client d'OVH.

# Serveurs de noms d'OVH et courrier (boîtes OVH). OVH a son propre type pour le SPF, qu'il
# publie en TXT.
protected_records = {
  ns-dns111 = { subdomain = "", fieldtype = "NS", ttl = 0, target = "dns111.ovh.net." }
  ns-ns111  = { subdomain = "", fieldtype = "NS", ttl = 0, target = "ns111.ovh.net." }
  mx-1      = { subdomain = "", fieldtype = "MX", ttl = 0, target = "1 mx1.mail.ovh.net." }
  mx-2      = { subdomain = "", fieldtype = "MX", ttl = 0, target = "5 mx2.mail.ovh.net." }
  mx-3      = { subdomain = "", fieldtype = "MX", ttl = 0, target = "100 mx3.mail.ovh.net." }
  spf       = { subdomain = "", fieldtype = "SPF", ttl = 0, target = "v=spf1 include:mx.ovh.com -all" }
}

# Ce qui sert rtgre.fr et www.rtgre.fr : « github-pages » ou « cluster ». C'est la seule valeur
# à changer pour basculer le site (docs/runbooks/basculer-rtgre-fr.md).
site_served_by = "cluster"

# Adresses que GitHub publie pour un domaine personnalisé. Elles ne servent que lorsque
# site_served_by vaut « github-pages ».
github_pages = {
  ipv4       = ["185.199.108.153", "185.199.109.153", "185.199.110.153", "185.199.111.153"]
  ipv6       = ["2606:50c0:8000::153", "2606:50c0:8001::153", "2606:50c0:8002::153", "2606:50c0:8003::153"]
  www_target = "kzsxwsjuldvcbsqt.github.io."
}

# Autres enregistrements, écrits tels quels.
records = {
  ftp = { subdomain = "ftp", fieldtype = "CNAME", ttl = 0, target = "rtgre.fr." }
}

# Noms qui désignent le cluster. « test » sert à valider le HTTPS avant la bascule.
cluster_subdomains = ["test"]
cluster_ttl        = 300
