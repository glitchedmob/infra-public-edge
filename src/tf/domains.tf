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
  comment = local.dns_record_comment
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "this_aaaa" {
  zone_id = data.cloudflare_zone.levizitting_com.id
  name    = local.hostname
  type    = "AAAA"
  content = local.ipv6_normalized
  comment = local.dns_record_comment
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "node_02_a" {
  zone_id = data.cloudflare_zone.levizitting_com.id
  name    = local.node_02_hostname
  type    = "A"
  content = vultr_instance.node_02.main_ip
  comment = local.dns_record_comment
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "node_02_aaaa" {
  zone_id = data.cloudflare_zone.levizitting_com.id
  name    = local.node_02_hostname
  type    = "AAAA"
  content = cidrhost("${vultr_instance.node_02.v6_main_ip}/128", 0)
  comment = local.dns_record_comment
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "public_edge_alias" {
  zone_id = data.cloudflare_zone.levizitting_com.id
  name    = "public-edge.${data.cloudflare_zone.levizitting_com.name}"
  type    = "CNAME"
  content = "${local.node_02_hostname}.${data.cloudflare_zone.levizitting_com.name}"
  comment = local.dns_record_comment
  proxied = false
  ttl     = 300

  depends_on = [
    cloudflare_dns_record.node_02_a,
    cloudflare_dns_record.node_02_aaaa,
  ]
}

resource "cloudflare_dns_record" "headscale_alias" {
  zone_id = data.cloudflare_zone.levizitting_com.id
  name    = local.headscale_hostname
  type    = "CNAME"
  content = cloudflare_dns_record.public_edge_alias.name
  comment = local.dns_record_comment
  proxied = false
  ttl     = 300
}
