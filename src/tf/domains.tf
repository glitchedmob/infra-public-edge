data "cloudflare_zone" "levizitting_com" {
  filter = {
    name = "levizitting.com"
  }
}

resource "cloudflare_dns_record" "this_a" {
  zone_id = data.cloudflare_zone.levizitting_com.id
  name    = local.hostname
  type    = "A"
  content = vultr_instance.this.main_ip
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "this_aaaa" {
  zone_id = data.cloudflare_zone.levizitting_com.id
  name    = local.hostname
  type    = "AAAA"
  content = local.ipv6_normalized
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "headscale_alias" {
  zone_id = data.cloudflare_zone.levizitting_com.id
  name    = local.headscale_hostname
  type    = "CNAME"
  content = local.vps_fqdn
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "flux" {
  zone_id = data.cloudflare_zone.levizitting_com.id
  name    = "flux"
  type    = "CNAME"
  content = local.vps_fqdn
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "dex" {
  zone_id = data.cloudflare_zone.levizitting_com.id
  name    = "dex"
  type    = "CNAME"
  content = local.vps_fqdn
  proxied = false
  ttl     = 300
}
