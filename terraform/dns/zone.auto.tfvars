# Zone rtgre.fr, chez OVH. Ce fichier ne contient aucun secret et il est suivi par Git.
ovh_endpoint = "ovh-eu"
zone         = "rtgre.fr"

# Courrier : boîtes OVH. Relevé le 2026-11-21.
mail_records = {
  mx-1 = { subdomain = "", fieldtype = "MX", ttl = 3600, target = "1 mx1.mail.ovh.net." }
  mx-2 = { subdomain = "", fieldtype = "MX", ttl = 3600, target = "5 mx2.mail.ovh.net." }
  mx-3 = { subdomain = "", fieldtype = "MX", ttl = 3600, target = "100 mx3.mail.ovh.net." }
  spf  = { subdomain = "", fieldtype = "TXT", ttl = 3600, target = "\"v=spf1 include:mx.ovh.com -all\"" }
}

# Site : rtgre.fr est servi par GitHub Pages jusqu'à la bascule vers le cluster (#57).
records = {
  pages-a-108     = { subdomain = "", fieldtype = "A", ttl = 3600, target = "185.199.108.153" }
  pages-a-109     = { subdomain = "", fieldtype = "A", ttl = 3600, target = "185.199.109.153" }
  pages-a-110     = { subdomain = "", fieldtype = "A", ttl = 3600, target = "185.199.110.153" }
  pages-a-111     = { subdomain = "", fieldtype = "A", ttl = 3600, target = "185.199.111.153" }
  pages-aaaa-8000 = { subdomain = "", fieldtype = "AAAA", ttl = 3600, target = "2606:50c0:8000::153" }
  pages-aaaa-8001 = { subdomain = "", fieldtype = "AAAA", ttl = 3600, target = "2606:50c0:8001::153" }
  pages-aaaa-8002 = { subdomain = "", fieldtype = "AAAA", ttl = 3600, target = "2606:50c0:8002::153" }
  pages-aaaa-8003 = { subdomain = "", fieldtype = "AAAA", ttl = 3600, target = "2606:50c0:8003::153" }
  pages-www       = { subdomain = "www", fieldtype = "CNAME", ttl = 3600, target = "kzsxwsjuldvcbsqt.github.io." }
  ftp             = { subdomain = "ftp", fieldtype = "CNAME", ttl = 3600, target = "rtgre.fr." }
}

# Noms qui désignent le cluster. « test » sert à valider le HTTPS avant la bascule.
cluster_subdomains = ["test"]
cluster_ttl        = 300
