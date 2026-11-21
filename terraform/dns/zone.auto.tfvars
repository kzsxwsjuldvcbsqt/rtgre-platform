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

# Site : rtgre.fr est servi par GitHub Pages jusqu'à la bascule vers le cluster (#57).
records = {
  pages-a-108     = { subdomain = "", fieldtype = "A", ttl = 0, target = "185.199.108.153" }
  pages-a-109     = { subdomain = "", fieldtype = "A", ttl = 0, target = "185.199.109.153" }
  pages-a-110     = { subdomain = "", fieldtype = "A", ttl = 0, target = "185.199.110.153" }
  pages-a-111     = { subdomain = "", fieldtype = "A", ttl = 0, target = "185.199.111.153" }
  pages-aaaa-8000 = { subdomain = "", fieldtype = "AAAA", ttl = 0, target = "2606:50c0:8000::153" }
  pages-aaaa-8001 = { subdomain = "", fieldtype = "AAAA", ttl = 0, target = "2606:50c0:8001::153" }
  pages-aaaa-8002 = { subdomain = "", fieldtype = "AAAA", ttl = 0, target = "2606:50c0:8002::153" }
  pages-aaaa-8003 = { subdomain = "", fieldtype = "AAAA", ttl = 0, target = "2606:50c0:8003::153" }
  pages-www       = { subdomain = "www", fieldtype = "CNAME", ttl = 0, target = "kzsxwsjuldvcbsqt.github.io." }
  ftp             = { subdomain = "ftp", fieldtype = "CNAME", ttl = 0, target = "rtgre.fr." }
}

# Noms qui désignent le cluster. « test » sert à valider le HTTPS avant la bascule.
cluster_subdomains = ["test"]
cluster_ttl        = 300
