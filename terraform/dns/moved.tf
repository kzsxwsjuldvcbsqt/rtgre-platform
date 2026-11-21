# Les enregistrements du site étaient écrits un par un : ils sont désormais calculés à partir de
# var.site_served_by. Ces blocs renomment leurs adresses dans le state, sans toucher à la zone.

moved {
  from = ovh_domain_zone_record.this["pages-a-108"]
  to   = ovh_domain_zone_record.this["site:a:0"]
}

moved {
  from = ovh_domain_zone_record.this["pages-a-109"]
  to   = ovh_domain_zone_record.this["site:a:1"]
}

moved {
  from = ovh_domain_zone_record.this["pages-a-110"]
  to   = ovh_domain_zone_record.this["site:a:2"]
}

moved {
  from = ovh_domain_zone_record.this["pages-a-111"]
  to   = ovh_domain_zone_record.this["site:a:3"]
}

moved {
  from = ovh_domain_zone_record.this["pages-aaaa-8000"]
  to   = ovh_domain_zone_record.this["site:aaaa:0"]
}

moved {
  from = ovh_domain_zone_record.this["pages-aaaa-8001"]
  to   = ovh_domain_zone_record.this["site:aaaa:1"]
}

moved {
  from = ovh_domain_zone_record.this["pages-aaaa-8002"]
  to   = ovh_domain_zone_record.this["site:aaaa:2"]
}

moved {
  from = ovh_domain_zone_record.this["pages-aaaa-8003"]
  to   = ovh_domain_zone_record.this["site:aaaa:3"]
}

moved {
  from = ovh_domain_zone_record.this["pages-www"]
  to   = ovh_domain_zone_record.this["site:www"]
}
